# DhanHQ Ruby Gem — Thorough Review & Protocol Verification

**Reviewed:** `dhanhq-client` @ `main` (`d78b00d`, gem version 4.1.0)
**Review date:** 2026-10-10
**Sources verified against:**

- Official v2 docs (all 22 pages): `https://dhanhq.co/docs/v2/`
- **Live OpenAPI 3.0.1 spec** (machine-readable, authoritative): `https://api.dhan.co/v2/v3/api-docs` — 47 paths
- **Sandbox OpenAPI spec**: `https://sandbox.dhan.co/v2/v3/api-docs` — 22 paths / 26 operations
- Live Market Feed / Full Market Depth / Order Updates / Annexure protocol pages
- Cross-validated with the official DhanHQ-py / DhanHQ-js SDKs

> The new `docs.dhanhq.co` site is a Docusaurus SPA whose JS bundles were not
> retrievable during the review; content was verified from the legacy docs
> domain and the two OpenAPI specs, which are the same API contract.

---

## 1. Verdict

**The gem's concept and architecture are sound and the "one gem, three legs" goal is met** — a single client now serves:

| Leg | Mechanism | Status after this review |
|---|---|---|
| Market connection & real live data | REST quotes/option chain/historical + `WS::Client` market feed | ✅ **Fixed** — was silently returning ticker-only data |
| Live execution | Orders / super / forever / multi / portfolio / funds / statements | ✅ Full coverage of all 47 live-spec paths |
| Sandbox execution | `mode: :sandbox` / `mode: :hybrid` against `sandbox.dhan.co/v2` | ✅ **Hardened** — now fails fast on endpoints the sandbox does not implement |

However, the review found **9 correctness bugs — including two that made the
live market feed and the entire market-depth stream unusable** — plus a rate
limiter that encoded the *swapped* daily limits of the Order and Data APIs.
All 9 are fixed in this changeset with 33 new spec examples; the full suite
passes **1302 examples, 0 failures**.

---

## 2. Architecture overview (what the gem actually is)

Far bigger than the name "dhanhq-client" suggests — it is a full trading SDK:

- **REST layer**: `Client` (Faraday) → per-tier `API_TYPE` (`order_api`,
  `data_api`, `quote_api`, `option_chain`, `non_trading_api`,
  `global_stocks_api`) each with its own shared `RateLimiter`; resources under
  `Resources::*`, models under `Models::*`, dry-validation `Contracts::*`.
- **Environment routing** (`Configuration#base_url_for(api_type)`): `:live`,
  `:sandbox`, `:hybrid` (data tiers → `api.dhan.co`, trading tiers →
  `sandbox.dhan.co`) + per-tier `environment_overrides`.
- **WebSocket layer**: `WS::Client` (market feed), `WS::Orders::Client`
  (order updates, `LoginReq MsgCode 42`), `WS::MarketDepth::Client`
  (20-level/200-level full market depth), all EventMachine + faye-websocket
  with reconnect/backoff/429-cooloff, subscription replay on reconnect,
  `SubState` diffing, ≤100 instruments per message.
- **Safety rails**: `LIVE_TRADING` gate (sandbox-exempt), order audit logs
  with `"target":"live"|"sandbox"`, dry-run simulator, risk pipeline
  (market hours, quantity, ASM/GSM, position limits, max loss),
  `ModificationLimitError` (25/order), auto correlation ids.
- **Extras**: technical-analysis + backtest engines, option analytics
  (Black-Scholes, max pain), skills layer, agent tool registry, MCP server,
  Rails generator, VitePress docs site.

This is the right shape for "market connection + real live data + sandbox
execution in a single gem".

### What the previous release already got right

- **Hybrid mode is the correct answer to the sandbox problem.** The sandbox
  OpenAPI spec confirms it has *no* quote/depth/option-chain endpoints, so
  "live data + sandbox execution" must be two hosts — exactly what `:hybrid`
  does.
- Sandbox-exempt `LIVE_TRADING` gate, per-tier rate limiting, subscription
  replay on reconnect, `healthy?`/`last_message_at` feed watchdogs,
  `correlationId` injection, write-retry opt-out with timeout reconciliation.

---

## 3. Critical findings (all fixed in this changeset)

### F1 — Every feed mode subscribed as *ticker* (data loss, silent)

`WS::Connection::SUB_CODES` mapped `ticker/quote/full → 15/15/15`. The official
docs define **15 = Ticker (LTP-only 8-byte packets), 17 = Quote (50 bytes),
21 = Full (162 bytes, 26 fields + 5-level depth)**. A user asking for
`mode: :full` got 8-byte LTP ticks and never knew.

```ruby
# before → after
{ ticker: 15, quote: 15, full: 15 }   # →  { ticker: 15, quote: 17, full: 21 }
```

### F2 — Unsubscribe sent the *disconnect* frame (connection killer)

`UNSUB_CODES` mapped every mode to **12** — the official "Disconnect Feed"
RequestCode. Any `unsubscribe_one`/`unsubscribe_many` call would have told the
server to *close the socket*, not drop instruments. Unsubscribe codes are the
subscribe code + 1: **16/18/22**. The market-depth client had the same bug
(`UNSUBSCRIBE_REQUEST_CODE = 12` → now **24**).

### F3 — Market depth decoder expected JSON; the wire is binary

`WS::MarketDepth::Decoder` did `JSON.parse(data)` and looked for
`"Type" => "depth_update"` — a protocol that does not exist. The official
Full Market Depth WebSocket sends **binary frames**:

```
12-byte header (little-endian):
  0: int16  message_length (frame size incl. header)
  2: uint8  response code  (41 = bid frame, 51 = ask frame, 50 = disconnect)
  3: uint8  exchange segment
  4: int32  security id
  8: uint32 sequence (ignore)
N × 16-byte rows:  float64 price | uint32 qty | uint32 orders
  20-level frame = 332 bytes, 200-level frame = 3212 bytes
  multiple frames may be stacked in one WS message — split by message_length
```

Every real frame would have died in `JSON::ParserError` → the entire feature
was dead against the live API. Rewritten as a binary decoder with stacked-frame
splitting and a disconnect-frame path; the client now emits
`:depth_update` per frame (with `side:`) and `:disconnect`.

### F4 — Index packets were dropped (NIFTY/SENSEX streamed nothing)

Index instruments (segment `IDX_I`) stream **response code 1** packets — but
`Decoder::FEED_KIND` had no entry for code 1, so index ticks hit
`handle_unknown` → `nil`. The docs *do* publish the layout:

```
32 bytes = 8B header + float32 latest | open | close(post-close only) | high | low | int32 updTime
```

Now decoded as `kind: :index` with `ltp/latest/day_open/day_high/day_low/day_close/ts`.

### F5 — Market status packet was unreachable dead code

The parser referenced `RESPONSE_CODES[:market_status]` but the hash never
defined `market_status: 7` — the `when` branch could never match. Code 7
(header-only frame signalling market open/close) is now parsed and decoded.

### F6 — Disconnect codes read big-endian

The feed's disconnect payload is a **uint16 little-endian** (805–809); the gem
read it with `unpack1("s>")` (big-endian signed), turning `805` into garbage
(`0x2503 → 9475`). Fixed in both the parser and `Packets::DisconnectPacket`.

### F7 — Frame header `message_length` read big-endian

The 8-byte header is little-endian throughout (`code u8 | length u16le |
segment u8 | securityId i32le`); the gem's BinData record declared
`endian :big` for the first three fields. `message_length` was never consumed
downstream, so this was latent — but it is now correct and covered by specs.

### F8 — Rate limits: the two daily caps were swapped

Official published limits vs. what `RateLimiter`/`Constants::RateLimit` had:

| Tier | Official | Gem (before) | Gem (after) |
|---|---|---|---|
| Order APIs | **10/s, 250/min, 1,000/hr, 7,000/day** | 10/s, ∞/min, ∞/hr, 100,000/day | 10/s, 250/min, 1,000/hr, 7,000/day |
| Data APIs | **5/s, 100,000/day** | 5/s, ∞/min, ∞/hr, 7,000/day | 5/s, 100,000/day |
| Quote APIs | 1/s (≤1,000 instruments/call) | 1/s | unchanged |
| Option chain | 1 unique request / 3 s | 1/3 s | unchanged |
| Non-trading | 20/s | 20/s | unchanged |

Both directions were wrong: data-heavy strategies would have been throttled
locally at 7k/day (allowed 100k), and order flows could fire up to 100k/day
before the local limiter intervened (Dhan cuts off at 7k with DH-904).

### F9 — `ws_market_feed` registered the tick callback after `start`

`Connection#start` spawns a background thread; the old code called
`ws.start` and only then `ws.on(:tick, &block)` — the first ticks could be
emitted before any handler existed. Callback registration now happens before
`start`.

---

## 4. Sandbox: what the official spec actually says

Verified from the sandbox OpenAPI spec (`sandbox.dhan.co/v2/v3/api-docs`,
22 paths) and Dhan's own FAQ:

- **It is not paper trading.** FAQ verbatim: *"The DhanHQ Sandbox is not a
  paper-trading environment and does not provide live-market simulation using
  virtual funds."* Orders pass through the real OMS/RMS validators and come
  back `REJECTED` with `omsErrorDescription` (e.g. lot-size violations), with
  `exchangeOrderId: "0"`.
- **Sandbox tokens are separate** and generated at the DevPortal
  (`developer.dhanhq.co` → Sandbox tab), 24h validity. The sandbox uses a
  single `access-token` header (no `client-id` header; the client id travels
  in the body as `dhanClientId` — the gem already injects it correctly).
- **No WebSocket of any kind on sandbox** — market feed, order updates and
  depth are production-only. The gem already pins WS URLs to production;
  note that under `:hybrid` the order-update stream reports your **real**
  account, not sandbox orders.
- **`GET /v2/profile` works on sandbox empirically** (gem's VCR cassette)
  although it is absent from the sandbox spec — treat as undocumented.

Full endpoint-by-endpoint matrix: see [GAP_ANALYSIS.md](GAP_ANALYSIS.md).

### Sandbox capability guard (new)

The gem used to send *everything* to the sandbox in `:sandbox` mode, including
endpoints the sandbox does not implement — those calls would die with an
opaque 404/405 or `DH-905`. The new `DhanHQ::SandboxCapabilities` matrix +
`DhanHQ::SandboxUnsupportedError` fail fast with an actionable message:

```ruby
DhanHQ.configure { |c| c.mode = :sandbox }
DhanHQ.client.super_orders.all
# => DhanHQ::SandboxUnsupportedError:
#    GET /v2/super/orders cannot run on the Dhan sandbox host
#    (https://sandbox.dhan.co/v2): endpoint GET /v2/super/orders* is not part
#    of the sandbox API surface. Use mode :hybrid (live market data + sandbox
#    execution), route this tier to production via config.environment_overrides,
#    or run in :live mode.
```

Blocked on sandbox (verified against the spec): super orders, alerts +
multi orders, `pnlExit`, `/ip/*`, `charts/rollingoption`, `/data/*` (ScanX),
`marketfeed/*`, `optionchain*`, `instrument/*`, `margincalculator/multi`,
`globalstocks/*`, `DELETE /positions` (exit-all), `GET /killswitch`.
Allowed: orders CRUD + slicing + correlation lookup, trades (3 variants),
forever orders, positions + convert, holdings, fundlimit, ledger,
`POST killswitch`, margincalculator (single), EDIS (4), charts historical +
intraday, profile (undocumented but works).

---

## 5. Medium-priority findings (documented, recommendations included)

| # | Finding | Recommendation |
|---|---|---|
| M1 | `Resources::IcebergOrders` (`/v2/orders/iceberg`) and `Resources::TwapOrders` (`/v2/orders/twap`) target endpoints that exist in **neither** the live OpenAPI spec (47 paths) **nor** any of the 22 official v2 docs pages. They will 404 against `api.dhan.co/v2`. | Verify against the live server with a real token; if they fail, deprecate with a clear error (the `TraderControl` precedent in this repo is the right pattern). |
| M2 | No application-level keepalive on the feed. The server pings every 10 s and closes after ~40 s of client silence; the WS driver auto-pongs protocol pings, so this *usually* works, but nothing detects a half-open socket proactively. | `Client#healthy?(stale_after: 45)` already exists — wire it into the reconnect loop (or an EM timer that force-recycles a stale connection), and consider exposing `DHAN_WS_IDLE_TIMEOUT`. |
| M3 | Depth caps not enforced client-side: twentydepth allows ≤50 instruments/connection, 200-depth exactly 1; the gem queues whatever it is given. | Guard in `WS::MarketDepth::Client#subscribe` with a clear error. |
| M4 | `ws_version = 1` is accepted by config but the v1 binary auth handshake (83-byte header + 500-byte token packet) is not implemented — a v1 setting yields a URL the server rejects. | Force `ws_version >= 2` (raise otherwise) or implement the v1 handshake. |
| M5 | The Global Stocks feed is half-wired: `Constants::Urls::WS_GLOBAL_STOCKS_FEED`, segment code and `MsgCode` values exist, but no `WS::GlobalStocks::Client`. | Either implement the client (TRADE=1, PREV_CLOSE=32, CIRCUIT_LIMIT=33, FIFTY_TWO_WEEK=36 message codes) or remove the constants. |
| M6 | Error-code map lacks `DH-911` (Invalid IP) which Dhan returns when order writes come from a non-whitelisted IP. | Add `TradingErrorCode::INVALID_IP = "DH-911"` and map it (helps users debug the static-IP requirement). |
| M7 | Historical windows are not validated client-side (intraday ≤ 90 days/call, `rollingoption` ≤ 30 days/call). Server-enforced, but pre-validating would save rate budget. | Add range checks to the two contracts. |
| M8 | `Sandbox` doc in the repo claims a MARKET order "stays PENDING" on sandbox; Dhan staff state market orders are not allowed on sandbox at all. | Keep using LIMIT orders in sandbox tests; expect RMS rejections with `omsErrorDescription`. |
| M9 | `Constants::Urls::ORIGIN` ("Origin header for WebSocket") is defined but never sent; harmless, but dead config invites confusion. | Send it as a WS handshake header or delete the constant. |

---

## 6. The three-legged usage story (as it works now)

```ruby
require "dhanhq"

DhanHQ.configure do |c|
  c.client_id     = ENV["DHAN_CLIENT_ID"]       # live client id
  c.access_token  = ENV["DHAN_ACCESS_TOKEN"]    # live token (24h)
  c.mode          = :hybrid                      # live data + sandbox execution
  # sandbox token (from https://developer.dhanhq.co → Sandbox tab) goes through
  # the same config when mode = :sandbox; under :hybrid the trading tiers use
  # whichever credentials you supply — supply the sandbox token here if your
  # live token must stay production-only (see docs/CONFIGURATION.md).
end

client = DhanHQ::Client.new

# ── Leg 1: real market data (api.dhan.co) ─────────────────────────────
client.market_feed.quote("NSE_EQ" => [11536], "NSE_FNO" => [49081])
client.option_chain.expiry_list(underlying_scrip: 13, underlying_seg: "IDX_I")
client.historical_data.intraday(security_id: "11536", exchange_segment: "NSE_EQ",
                                instrument: "EQUITY", interval: "5",
                                from_date: "2026-09-10", to_date: "2026-10-10")

# ── Leg 2: live market feed (WebSocket, api-feed.dhan.co) ─────────────
client.ws_market_feed(mode: :full) do |tick|   # RequestCode 21 → 26 fields + 5-level depth
  puts tick[:security_id], tick[:ltp], tick[:oi], tick[:bid], tick[:ask]
end
# index instruments now stream too (kind: :index) — NIFTY 50 = IDX_I:13
feed = client.ws_market_feed(mode: :ticker)
feed.subscribe_one(segment: "IDX_I", security_id: "13")
feed.health   # => { connected:, healthy:, last_message_at:, subscription_count: ... }

# 20-level full market depth (binary protocol, now actually decoded)
depth = client.ws_market_depth(symbols: ["NSE_FNO:49081"])
depth.on(:depth_update) { |frame| puts frame[:side], frame[:levels].first }

# ── Leg 3: sandbox execution (sandbox.dhan.co, no real money) ─────────
client.orders.create(transaction_type: "BUY", exchange_segment: "NSE_EQ",
                     product_type: "INTRADAY", order_type: "LIMIT",
                     security_id: "11536", quantity: 5, price: 225.0)
# → validated by the real OMS/RMS; expect REJECTED + omsErrorDescription for
#   invalid payloads instead of silent failures.

# Endpoints the sandbox cannot serve fail fast with guidance:
client.super_orders.all rescue DhanHQ::SandboxUnsupportedError => e
```

---

## 7. Verification

- **Full suite:** `1302 examples, 0 failures` (was `1269, 0` before this changeset).
- **New specs (33 examples):**
  - `spec/dhan_hq/ws/feed_decoder_spec.rb` — byte-accurate ticker/index/quote/full/market-status/prev-close/disconnect decoding, header endianness, unknown codes.
  - `spec/dhan_hq/ws/market_depth/decoder_spec.rb` — binary FMD frames: single/stacked/20-level/disconnect/truncated/JSON-input.
  - `spec/dhan_hq/ws/connection_request_codes_spec.rb` — 15/17/21 sub codes, 16/18/22 unsub codes, 12 never used, ≤100 batching.
  - `spec/dhan_hq/sandbox_capabilities_spec.rb` — full matrix incl. method-specific rules.
  - `spec/dhan_hq/client_sandbox_guard_spec.rb` — fail-fast in `:sandbox`, pass-through in `:hybrid`/`:live`.
  - `spec/dhan_hq/rate_limiter_spec.rb` — corrected official limits (7k/day orders, 100k/day data, 250/min + 1,000/hr windows enforced).
- Note: the 12 `spec/rubocop/**` examples fail to load in this review
  environment due to a `prism` gem version skew (dev dependency, unrelated to
  the gem's runtime code); excluded from the runs above.

---

## 8. Priority checklist for maintainers

1. ✅ **Done in this changeset** — F1–F9 fixes + sandbox guard + docs.
2. **Verify iceberg/twap on a live token** (M1) — decide keep vs deprecate.
3. **Wire the `healthy?` watchdog into reconnection** (M2).
4. **Depth caps guard** (M3) and **Global Stocks feed decision** (M5).
5. **Add `DH-911` + historical window validation** (M6, M7).
6. Schedule a one-time manual pass with real credentials per host:
   `bin/call_all_endpoints.rb` (read-only) against live **and** sandbox,
   capturing which sandbox endpoints 200 vs 404 — then commit the results
   into `docs/ENDPOINTS_AND_SANDBOX.md`.
