# Endpoint Gap Analysis — dhanhq-client vs official DhanHQ v2

**Legend:** ✅ implemented & matches spec · 🟡 implemented with caveats · ❌ missing · ⛔ not available on sandbox
**Reference surfaces:** live OpenAPI `api.dhan.co/v2/v3/api-docs` (47 paths) · sandbox OpenAPI `sandbox.dhan.co/v2/v3/api-docs` (22 paths / 26 ops) · `dhanhq.co/docs/v2/` (22 pages)

---

## 1. Trading & account APIs (order_api tier)

| # | Official endpoint | Gem resource → method | Gem status | Sandbox |
|---|---|---|---|---|
| 1 | `POST /orders` | `Resources::Orders#create` (+ `Models::Order.place`) | ✅ | ✅ |
| 2 | `PUT /orders/{order-id}` | `Orders#modify` | ✅ | ✅ |
| 3 | `DELETE /orders/{order-id}` | `Orders#cancel` | ✅ | ✅ |
| 4 | `GET /orders` (order book) | `Orders#all` | ✅ | ✅ |
| 5 | `GET /orders/{order-id}` | `Orders#find` | ✅ | ✅ |
| 6 | `GET /orders/external/{correlation-id}` | `Orders#find_by_correlation_id` | ✅ | ✅ |
| 7 | `POST /orders/slicing` | `Orders#slicing` | ✅ | ✅ |
| 8 | `GET /trades` (trade book) | `Resources::Trades#all` | ✅ | ✅ |
| 9 | `GET /trades/{order-id}` | `Trades#find` | ✅ | ✅ |
| 10 | `GET /trades/{from}/{to}/{page}` (history) | `Resources::Statements#trade_history` | ✅ | ✅ |
| 11 | `POST /super/orders` | `Resources::SuperOrders#create` | ✅ | ⛔ (live only) |
| 12 | `PUT /super/orders/{order-id}` | `SuperOrders#modify` | ✅ | ⛔ |
| 13 | `DELETE /super/orders/{order-id}/{order-leg}` | `SuperOrders#cancel` (leg-aware) | ✅ | ⛔ |
| 14 | `GET /super/orders` | `SuperOrders#all` | ✅ | ⛔ |
| 15 | `POST /forever/orders` (GTT) | `Resources::ForeverOrders#create` | ✅ | ✅ |
| 16 | `PUT /forever/orders/{order-id}` | `ForeverOrders#modify` | ✅ | ✅ |
| 17 | `DELETE /forever/orders/{order-id}` | `ForeverOrders#cancel` | ✅ | ✅ |
| 18 | `GET /forever/orders` | `ForeverOrders#all` / `#find` | ✅ | ✅ |
| 19 | `POST /alerts/orders` (conditional trigger) | `Resources::AlertOrders#create` | ✅ | ⛔ |
| 20 | `PUT /alerts/orders/{alertId}` | `AlertOrders#update` | ✅ | ⛔ |
| 21 | `DELETE /alerts/orders/{alertId}` | `AlertOrders#delete` | ✅ | ⛔ |
| 22 | `GET /alerts/orders/{alertId}` | `AlertOrders#find` | ✅ | ⛔ |
| 23 | `GET /alerts/orders` | `AlertOrders#all` | ✅ | ⛔ |
| 24 | `POST /alerts/multi/orders` (basket, spec-only) | `Resources::MultiOrders#create` | ✅ | ⛔ |
| 25 | `GET /holdings` | `Resources::Holdings#all` | ✅ | ✅ |
| 26 | `GET /positions` | `Resources::Positions#all` | ✅ | ✅ |
| 27 | `POST /positions/convert` | `Positions#convert` | ✅ | ✅ |
| 28 | `DELETE /positions` (exit all) | `Positions#exit_all` | ✅ | ⛔ (spec gap → guarded) |
| 29 | `GET /fundlimit` | `Resources::Funds#all` | ✅ | ✅ |
| 30 | `POST /margincalculator` | `Resources::MarginCalculator#calculate` | ✅ | ✅ |
| 31 | `POST /margincalculator/multi` | `MarginCalculator#calculate_multi` | ✅ | ⛔ (spec gap → guarded) |
| 32 | `GET /ledger?from-date&to-date` | `Resources::Statements#ledger` | ✅ | ✅ |
| 33 | `GET /edis/tpin` | `Resources::Edis#tpin` | ✅ | ✅ |
| 34 | `POST /edis/form` | `Edis#form` | ✅ | ✅ |
| 35 | `POST /edis/bulkform` | `Edis#bulk_form` | ✅ | ✅ |
| 36 | `GET /edis/inquire/{isin}` | `Edis#inquire` | ✅ | ✅ |
| 37 | `POST /killswitch?killSwitchStatus=` | `Resources::KillSwitch#update` (query-param per docs) | ✅ | ✅ |
| 38 | `GET /killswitch` | `KillSwitch#status` | ✅ | ⛔ (spec gap → guarded) |
| 39 | `POST /pnlExit` | `Resources::PnlExit#configure` | ✅ | ⛔ |
| 40 | `DELETE /pnlExit` | `PnlExit#stop` | ✅ | ⛔ |
| 41 | `GET /pnlExit` | `PnlExit#status` | ✅ | ⛔ |
| 42 | `POST /ip/setIP` · `PUT /ip/modifyIP` · `GET /ip/getIP` | `Resources::IPSetup#set/#update/#current` | ✅ | ⛔ |
| 43 | `GET /profile` (docs-only, not in spec) | `Resources::Profile#find` | ✅ | 🟡 works empirically, undocumented |

**Result: all 47 live-spec paths are implemented.** No missing trading/account endpoints.

**Gem extras not in the official v2 spec** (kept but flagged):

| Gem resource | Path | Status |
|---|---|---|
| `Resources::IcebergOrders` | `/v2/orders/iceberg` | 🟡 absent from live spec **and** docs — verify live or deprecate (see REVIEW.md M1) |
| `Resources::TwapOrders` | `/v2/orders/twap` | 🟡 same |
| `Resources::TraderControl` | `/trader-control` | ✅ intentionally raises (legacy shim → use KillSwitch/PnlExit) |
| `Auth::TokenRenewal` | `POST /RenewToken` (docs-only) | ✅ |

---

## 2. Market data APIs (data_api / quote_api / option_chain tiers)

| # | Official endpoint | Gem resource → method | Gem status | Sandbox |
|---|---|---|---|---|
| 1 | `POST /marketfeed/ltp` | `Resources::MarketFeed#ltp` | ✅ | ⛔ |
| 2 | `POST /marketfeed/ohlc` | `MarketFeed#ohlc` | ✅ | ⛔ |
| 3 | `POST /marketfeed/quote` | `MarketFeed#quote` (own 1/s tier) | ✅ | ⛔ |
| 4 | `POST /optionchain` | `Resources::OptionChain#get` (own 1/3s tier) | ✅ | ⛔ |
| 5 | `POST /optionchain/expirylist` | `OptionChain#expiry_list` | ✅ | ⛔ |
| 6 | `POST /charts/historical` | `Resources::HistoricalData#daily` | ✅ | ✅ |
| 7 | `POST /charts/intraday` | `HistoricalData#intraday` | ✅ | ✅ |
| 8 | `POST /charts/rollingoption` | `Resources::ExpiredOptionsData#fetch` | ✅ | ⛔ |
| 9 | `POST /data/companyinfo` (ScanX) | `Resources::ScanX#company_info` | ✅ | ⛔ |
| 10 | `POST /data/marketmovers` | `ScanX#market_movers` | ✅ | ⛔ |
| 11 | `POST /data/newsheadline` | `ScanX#news_headlines` | ✅ | ⛔ |
| 12 | `POST /data/technical` | `ScanX#technical_data` | ✅ | ⛔ |
| 13 | `GET /instrument/{exchangeSegment}` (+ CSV masters) | `Resources::Instruments` / `Models::Instrument` | ✅ | ⛔ |

Caveats: intraday windows >90 days and `rollingoption` >30 days are
server-rejected — not pre-validated client-side (REVIEW.md M7).

---

## 3. Global Stocks — US equities (`globalstocks_api` tier, always production)

| # | Official endpoint | Gem resource | Gem status | Sandbox |
|---|---|---|---|---|
| 1 | `GET/POST /globalstocks/orders` | `Resources::GlobalStocks::Orders` | ✅ | ⛔ |
| 2 | `GET/PUT/DELETE /globalstocks/orders/{order-id}` | `GlobalStocks::Orders` | ✅ | ⛔ |
| 3 | `POST /globalstocks/transEstimate` | `GlobalStocks::MarginCalculator#trans_estimate` | ✅ | ⛔ |
| 4 | `POST /globalstocks/margincalculator` | `GlobalStocks::MarginCalculator#calculate` | ✅ | ⛔ |
| 5 | `GET /globalstocks/trades` | `GlobalStocks::Trades#all` | ✅ | ⛔ |
| 6 | `GET /globalstocks/trades/{security-id}` | `GlobalStocks::Trades#find` | ✅ | ⛔ |
| 7 | `GET /globalstocks/marketstatus` | `GlobalStocks::MarketStatus` | ✅ | ⛔ |
| 8 | `GET /globalstocks/holdings` | `GlobalStocks::Holdings` | ✅ | ⛔ |
| 9 | `GET /globalstocks/fundlimit` | `GlobalStocks::Funds` | ✅ | ⛔ |

Gap: the **Global Stocks live feed WebSocket** (`wss://global-stocks-api-feed.dhan.co`,
msg codes TRADE=1 / PREV_CLOSE=32 / CIRCUIT_LIMIT=33 / FIFTY_TWO_WEEK=36) has
constants defined in `Constants::GlobalStocks` but **no client implementation**
(REVIEW.md M5).

---

## 4. WebSocket surfaces

| Stream | Official | Gem | Status | Notes |
|---|---|---|---|---|
| Market feed v2 | `wss://api-feed.dhan.co?version=2&token&clientId&authType=2` | `WS::Client` / `Client#ws_market_feed` | ✅ **fixed** | Sub codes 15/17/21, unsub 16/18/22 (was 15/15/15 + 12); index (code 1) + market status (code 7) packets now decoded; LE header/disconnect fixed; ≤100 instruments/message ✅; reconnect + resubscribe ✅ |
| Market feed v1 | binary auth handshake | — | 🟡 | Not implemented; `ws_version=1` should be rejected (M4) |
| Order updates | `wss://api-order-update.dhan.co` + `LoginReq MsgCode 42` | `WS::Orders::Client` | ✅ | SELF (token) + PARTNER (secret) auth ✅; order tracker, status/execution events ✅; production-only (no sandbox WS) |
| 20-level depth | `wss://depth-api-feed.dhan.co/twentydepth` (≤50 instruments) | `WS::MarketDepth::Client` | ✅ **fixed** | Was JSON-decoding a binary protocol; now decodes 332-byte frames (12B header + f64 rows), unsub 24 (was 12); caps not enforced client-side (M3) |
| 200-level depth | `wss://full-depth-api.dhan.co/twohundreddepth` (1 instrument) | same client via `market_depth_level: 200` | ✅ **fixed** | 3212-byte frames decode with the same parser |
| Global Stocks feed | `wss://global-stocks-api-feed.dhan.co` | — | ❌ | Constants exist, client missing (M5) |

Binary packet coverage on the main feed (v2 spec → `WS::Packets`):

| Response code | Packet | Size | Decoder |
|---|---|---|---|
| 1 | Index | 32 B | ✅ `decode_index` (was dropped) |
| 2 | Ticker | 16 B | ✅ |
| 3 | Depth (5-level) | 112 B | ✅ (new; only on RequestCode 19 subscriptions) |
| 4 | Quote | 50 B | ✅ |
| 5 | Open interest | 12 B | ✅ |
| 6 | Prev close | 16 B | ✅ (f32 per v2 spec) |
| 7 | Market status | 8 B | ✅ (was dead code) |
| 8 | Full | 162 B | ✅ (26 fields + 5×20B depth) |
| 50 | Disconnect | 10 B | ✅ (LE u16; was BE) |
| 41/51 | FMD bid/ask frames | 332/3212 B | ✅ in `MarketDepth::Decoder` |

---

## 5. Authentication surface

| Flow | Official | Gem | Status |
|---|---|---|---|
| Generate access token | `POST https://auth.dhan.co/app/generateAccessToken?token&dhanClientId&pin&totp` | `Auth::TokenGenerator` / `Client#generate_access_token` | ✅ |
| TOTP self-generation | (documented pattern) | `Auth::TokenGenerator` (rotp) | ✅ |
| Renew token | `POST /v2/RenewToken` | `Auth::TokenRenewal` | ✅ |
| Auto-renewal + 401 retry | — | `Auth::TokenManager` + `Client#with_auth_retry` + `access_token_provider` | ✅ |
| Partner consent flow (`/app/generate-consent`, `/consent-login`, `/consumeApp-consent`) | docs | — | ❌ (partner-only; low priority) |
| Static IP management | `/ip/*` | `IPSetup` (with `ipFlag`, `dhanClientId` per docs) | ✅ |
| Postback webhook parsing | docs | `Models::Postback.parse` (parsing only, no server) | ✅ scope-limited |

---

## 6. Rate limits & error codes

**Rate limits (fixed in this changeset):**

| Tier | Official | Gem before | Gem now |
|---|---|---|---|
| order_api | 10/s · 250/min · 1,000/hr · 7,000/day | 10/s · ∞ · ∞ · 100,000/day | 10/s · 250/min · 1,000/hr · 7,000/day ✅ |
| global_stocks_api | = order_api | ∞ daily | = order_api ✅ |
| data_api | 5/s · 100,000/day | 5/s · 7,000/day | 5/s · 100,000/day ✅ |
| quote_api | 1/s | 1/s | 1/s ✅ |
| option_chain | 1 unique req / 3 s | 1/3 s | 1/3 s ✅ |
| non_trading_api | 20/s | 20/s | 20/s ✅ |
| WS | 5 conns × 5,000 instruments, ≤100/msg | ≤100/msg | ≤100/msg ✅ (conn caps documented in `Constants::RateLimit::MARKET_FEED`) |

**Error codes:** `DH-901`–`DH-910` + `DH-1111` and the data-API 800/804–814
series are all mapped to typed exception classes in
`Constants::DHAN_ERROR_MAPPING`. Missing: `DH-911` (Invalid IP) — recommended
addition (REVIEW.md M6). Sandbox-specific behaviour (RMS rejections delivered
as `orderStatus: REJECTED` + `omsErrorDescription`, raw 403/503 infra errors)
surfaces through the same error pipeline.

---

## 7. Sandbox surface — definitive matrix (from the official sandbox OpenAPI spec)

**Sandbox base:** `https://sandbox.dhan.co/v2` · single `access-token` header ·
`dhanClientId` in body · tokens from `developer.dhanhq.co` (24h) ·
**no WebSocket** · **no market data quotes** · **not paper trading** (real
OMS/RMS validation, orders get rejected with `omsErrorDescription`,
`exchangeOrderId: "0"`).

**In the sandbox (22 paths / 26 ops — all implemented in the gem):**
`POST/GET/PUT/DELETE /orders`, `GET /orders/{id}`, `GET /orders/external/{corr}`,
`POST /orders/slicing`, `GET /trades`, `GET /trades/{order-id}`,
`GET /trades/{from}/{to}/{page}`, `POST/GET/PUT/DELETE /forever/orders*`,
`GET /positions`, `POST /positions/convert`, `GET /holdings`, `GET /fundlimit`,
`GET /ledger`, `POST /killswitch`, `POST /margincalculator`, `POST /edis/form`,
`POST /edis/bulkform`, `GET /edis/tpin`, `GET /edis/inquire/{isin}`,
`POST /charts/intraday`, `POST /charts/historical`.

**NOT in the sandbox (gem now raises `DhanHQ::SandboxUnsupportedError`):**
super orders · alerts + multi orders · pnlExit · `/ip/*` ·
`charts/rollingoption` · `/data/*` (ScanX) · `marketfeed/*` · `optionchain*` ·
`instrument/*` · `margincalculator/multi` · `globalstocks/*` ·
`DELETE /positions` · `GET /killswitch` · all WebSockets.

**Mode guidance:** use `:hybrid` for strategy rehearsal (live prices +
sandbox execution), `:sandbox` for pure API-contract integration tests, and
remember that under `:hybrid` the order-update WebSocket streams your **real**
account.
