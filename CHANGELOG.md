## [4.1.1] - 2026-10-11

### Fixed — pre-trade risk pipeline

- **The risk checks only saw parameters whose key happened to be a single lowercase word.** Checks read snake_case String keys (`"order_type"`, `"product_type"`, `"security_id"`), but orders arrive as camelCase Strings (models) or Symbols (direct resource calls). `OrderType`, `ProductSupport` and `Concentration` therefore never ran on real orders, and Symbol-keyed callers failed `Quantity must be > 0` on a valid quantity — which blocked every `SuperOrder.create`. `OrderAudit` now normalises keys before running the pipeline.
- **Risk-reducing orders are never blocked by a limit.** An order on the opposite side of an open position, same security / segment / product, for no more than the position size, skips the size caps, open-position count, daily loss, concentration and ASM/GSM checks; it still gets trading-permission, product, order-type, quantity > 0 and market-hours validation. Previously a stop-out could be refused precisely because the account was over its loss or position limit.
- **`OrderType` accepts `STOP_LOSS` and `STOP_LOSS_MARKET`** (was `MARKET`/`LIMIT` only). With the key fix above, the old list would have rejected every stop-loss order.
- **`Concentration` matches positions by security id** (and segment) when the order names no trading symbol, and counts the new order's notional; it compared a trading symbol against a security id and so never matched an order. A MARKET entry (which carries no price) is priced from its trigger price or the instrument's LTP; an entry that cannot be priced is refused rather than counted as zero exposure.
- **`MaxLoss` counts realized plus unrealized P&L** for the day (was unrealized only).
- **Positions are fetched once per order** and shared by every check (was up to three `GET /v2/positions` calls per order).
- **`SuperOrder.create`, `IcebergOrder.create` and `TwapOrder.create` raised `ArgumentError` after a successful placement** (Ruby 3 keyword arguments: the attributes hash was splatted into keywords). The order existed at Dhan while the caller saw an exception — a retry would duplicate it. The super-order spec stubbed `.new` with the same broken signature, which hid it.

### Fixed — endpoint wire format and error mapping

- **Data-API error codes sent as integers never matched the error mapping.** Dhan's data APIs answer with numeric codes (`{"errorCode":807,"errorMessage":"Token expired"}` — see `spec/vcr_cassettes/client/error_806.yml`), but `ResponseHelper#handle_error` compared them against string-keyed `DHAN_ERROR_MAPPING`, so every integer code fell through to the HTTP-status fallback: token expiry (807) surfaced as `InvalidAuthenticationError`, invalid expiry date (811) as a generic `InputExceptionError`, and so on. The code is now normalized with `.to_s` before the lookup. New wire-format specs in `spec/dhan_hq/resources/historical_data_spec.rb` and `expired_options_data_spec.rb` cover the mapping.
- **`Resources::Instruments#by_segment` swallowed HTTP errors.** On 4xx/5xx it returned the raw JSON error body as if it were CSV — no exception, unlike every other resource. Failures now raise the status-mapped `DhanHQ::Error` subclass (`NotFoundError`, `InvalidAuthenticationError`, …). New spec in `spec/dhan_hq/resources/instruments_spec.rb`.
- **`Resources::MarginCalculator#calculate_multi` sent nested `scripList` entries in snake_case.** Only top-level keys were camelized, so the API received `security_id`/`exchange_segment` inside each scrip (the `Models::Margin` layer pre-camelized as a workaround; the raw resource did not). The resource now deep-camelizes like `multi_orders` does for its legs. New spec in `spec/dhan_hq/resources/margin_calculator_spec.rb`.
- New WebMock wire-format specs for every non-order REST endpoint — funds, holdings, trades, positions, profile, statements, market feed (ltp/ohlc/quote), option chain, charts, expired options, margin calculator, instruments, EDIS, IP setup, kill switch — asserting method, path, headers, body shape, param camelization/titleization, and typed error mapping. (Orders endpoints excluded per scope.)

### Fixed — authentication

- **`DhanHQ::Auth.renew_token` called the wrong URL.** `conn.post("/RenewToken")` on the `https://api.dhan.co/v2` base made Faraday drop `/v2` (a leading slash is an absolute path), so renewals hit `https://api.dhan.co/RenewToken`. It now requests `/v2/RenewToken` with **GET**, matching Dhan's documented curl example (`dhanhq.co/docs/v2/authentication`) and the official Python SDK (`dhanhq` 2.3.0). `generate_access_token` also uses a relative path now.
- **Successful auth responses returned `{}`.** The auth connection had no JSON parsing, so the body arrived as a string and `handle_response` discarded it — the new `accessToken` was lost on every successful renewal or generation. Bodies are now parsed regardless of `Content-Type`.
- **Auth failures are typed by cause.** 429 raises `DhanHQ::RateLimitError`, 5xx `DhanHQ::InternalServerError`, timeouts and connection failures `DhanHQ::NetworkError`; only refused credentials raise `DhanHQ::InvalidAuthenticationError`. Previously every failure, including outages, looked like bad credentials. All remain `DhanHQ::Error` subclasses, and `response_body` now carries the parsed error payload.
- **Auth requests have timeouts** (`DHAN_CONNECT_TIMEOUT` / `DHAN_READ_TIMEOUT` / `DHAN_WRITE_TIMEOUT`, defaults 10/30/30s, as `Client#build_connection`). They were unbounded.
- New `spec/dhan_hq/auth_spec.rb` covers both endpoints, error mapping, timeouts and `Auth::TokenRenewal`; the auth module previously had no specs.

### Added

- **Configurable risk limits** — `config.risk_limits = { max_quantity:, max_notional:, max_open_positions:, daily_max_loss:, max_concentration_pct: }` or `DHAN_RISK_MAX_QUANTITY`, `DHAN_RISK_MAX_NOTIONAL`, `DHAN_RISK_MAX_OPEN_POSITIONS`, `DHAN_RISK_DAILY_MAX_LOSS`, `DHAN_RISK_MAX_CONCENTRATION_PCT`. Defaults are unchanged (10 units, ₹1,00,000 notional, 20 positions, ₹50,000 daily loss, 25%). Unknown names or non-positive values raise `ArgumentError` at configuration time.

### Upgrade notes

- **`max_quantity` defaults to 10 units, so one NIFTY lot (75) is rejected** on any order whose instrument resolves. This was already true for camelCase-keyed orders before this release; it now applies to every key style. F&O users must raise `max_quantity` (in units, not lots) and usually `max_notional`.
- Checks that never ran before now run on every order: `OrderType`, `ProductSupport` (CO/BO support flags) and `Concentration` (one extra `GET /v2/fundlimit` per new-exposure order).
- A risk-check failure still fails open: if the instrument lookup or a positions/funds fetch raises, the pipeline is skipped and logged as `DHAN_RISK_CHECK_SKIPPED` (unchanged behaviour).

### Fixed — WebSocket feed protocol and runtime

- **Live Market Feed subscribed every mode as ticker** — `WS::Connection::SUB_CODES` mapped `ticker/quote/full` all to RequestCode **15** (LTP-only packets), so `mode: :full` silently delivered 8-byte ticker ticks instead of the 162-byte 26-field + 5-level-depth packets. Each mode now maps to its documented code: **15 / 17 / 21**.
- **Unsubscribe sent the disconnect frame** — `UNSUB_CODES` used RequestCode **12** (the official Disconnect Feed code), so any per-instrument unsubscribe told the server to close the socket. Unsubscribe codes are now subscribe+1: **16 / 18 / 22**. `WS::MarketDepth::Client::UNSUBSCRIBE_REQUEST_CODE` likewise fixed 12 → **24**.
- **Market depth decoder parsed JSON; the wire is binary** — `WS::MarketDepth::Decoder` expected `{"Type":"depth_update"}` JSON that the Full Market Depth WebSocket never sends. 4.1.1 shipped a binary decoder too; the two are reconciled here: frames decode per the documented 12-byte little-endian header + 16-byte rows, split by `message_length` (with `side:`, `levels:`, `disconnect_code:`), and the client still emits one merged-book `:depth_update` per instrument (`bids`, `asks`, `best_bid`, `best_ask`, `spread`) plus `:disconnect`.
- **Index packets were dropped** — IDX_I instruments stream response-code-1 packets, but `Decoder::FEED_KIND` had no mapping, so NIFTY/SENSEX subscriptions produced nothing. Index packets now decode per the documented 32-byte layout (latest/open/close/high/low + update time) as `kind: :index`.
- **Market-status packets were unreachable** — the parser referenced a `RESPONSE_CODES[:market_status]` key that was never defined; code 7 (market open/close notification) now parses and decodes.
- **Disconnect codes read big-endian** — the disconnect payload is a uint16 little-endian (805–809); it was read as big-endian signed, mangling the codes (805 → 9475). Fixed in the parser and `Packets::DisconnectPacket`; `Packets::Header` is now little-endian throughout per the spec.
- **Rate limits follow the stricter of Dhan's two doc sites.** dhanhq.co/docs/v2 lists Order 10/s, 250/min, 1,000/hr, 7,000/day and Data 5/s, 100,000/day; docs.dhanhq.co lists Order 10/s, 100,000/day and Data 5/s, 7,000/day. `RateLimiter` and `Constants::RateLimit` now apply the stricter value per tier: **Order 10/s, 250/min, 1,000/hr, 7,000/day; Data 5/s, 7,000/day** (was Order 100,000/day with no minute/hour caps, Data 7,000/day).
- **`ws_market_feed` tick-callback race** — the tick callback was registered after the socket thread started; it is now registered before `start`, so the first ticks can no longer be dropped.
- **`WS::Registry#stop_all` deadlock** — the registry mutex is no longer held while clients are stopped. Both `WS::Client#stop` and `WS::Orders::Client#stop` call `Registry.unregister` (same mutex) from `stop`, so stopping under the mutex raised a recursive-locking `ThreadError` that the per-client rescue silently swallowed — killing the market feed's `emit(:close, true)` notification (orders clients emit before unregistering, so only theirs survived). `stop_all` now snapshots and clears the client list under the mutex, then stops each client outside it; unregister during that later stop is a no-op delete. Regression spec `spec/dhan_hq/ws/registry_stop_all_spec.rb` covers self-unregistering clients, close-listener notification for both orderings, failing-client isolation, and the empty-registry case.
- **Typed order guards on derivative order models** — `SuperOrder`, `ForeverOrder`, `TwapOrder` and `IcebergOrder` id guards now raise `DhanHQ::OrderError` (was bare `RuntimeError`), so `rescue DhanHQ::Error` catches them consistently with `Models::Order`. Guard assertions strengthened to the error class; new coverage for `TwapOrder`/`IcebergOrder` (`spec/dhan_hq/models/typed_order_guards_spec.rb`).
- **`RateLimiter` deadlocked once a minute/hour/day bucket was exhausted.** `throttle!` waited for the reset while holding the per-tier mutex that the reset thread also needs, so the first caller past a cap — and every later caller on that tier — blocked forever. Newly reachable with the 250/min order cap (polling the order book or positions at 5/s hits it in under a minute). Admission is now decided under the mutex and every wait happens outside it.
- **Contract loading failed without a UTF-8 locale.** `Contract::SpecLoader` and `JsonLoader` read files with the process's default external encoding; under `LANG` unset / `C` (minimal Docker images, cron) that is US-ASCII and the vendored specs' non-ASCII bytes raised, failing every request. Files are now read as UTF-8 explicitly.
- **A `nil` request body skipped contract validation** for operations with a required body (`client.post("/v2/orders", nil)`). It is now validated as `{}`.
- **Sandbox requests in `:hybrid` mode carry the sandbox client id again.** The contract-validation path injected `dhanClientId` from the production `client_id`, undoing 4.1.1's per-environment credentials; injection now uses the request tier's client id and rebinds a production id.
- **Market depth unsubscribe is 24, not 25.** 4.1.1 changed it to 25 following docs.dhanhq.co; the official DhanHQ-py SDK (2.3.0, `fulldepth.py`) sends `request_code + 1` = 24, matching the dhanhq.co/docs/v2 annexure and the WS protocol manifest.
- **One sandbox guard.** 4.1.1's path-prefix deny-list (`Constants::SANDBOX_UNSUPPORTED_PATH_PREFIXES`) is replaced by the contract-derived `SandboxCapabilities`, which is method-aware and fails closed. `GET /killswitch`, `DELETE /positions` and the undocumented iceberg/TWAP endpoints are now refused on the sandbox as well.

### Added — sandbox guard and review docs

- **Sandbox capability guard** — `DhanHQ::SandboxCapabilities` (derived from the official sandbox OpenAPI spec at `sandbox.dhan.co/v2/v3/api-docs`) and `DhanHQ::SandboxUnsupportedError`. Requests that would target the sandbox host for endpoints the sandbox does not implement (super orders, alerts/multi orders, pnlExit, `/ip/*`, `charts/rollingoption`, `/data/*`, `marketfeed/*`, `optionchain*`, `instrument/*`, `margincalculator/multi`, `globalstocks/*`, `DELETE /positions`, `GET /killswitch`) now fail fast with an actionable message instead of an opaque 404/DH-905. `:hybrid` mode is unaffected — its data tiers keep resolving to production.
- **Review documentation** — `REVIEW.md` (protocol-verified review with findings F1–F9 and recommendations M1–M9) and `GAP_ANALYSIS.md` (endpoint-by-endpoint matrix: 47 live-spec paths ✅, sandbox matrix, WS packet coverage, auth surface, rate limits, error codes).

### Contract-first architecture (branch `contract-first`)

The gem's wire knowledge now flows from **machine-readable contracts** instead of
hand transcription. See [CONTRACT_FIRST.md](CONTRACT_FIRST.md) for the
architecture, [contracts/overlays/README.md](contracts/overlays/README.md) for
the vendor-spec patch log, and the generated
[docs/ENDPOINTS.md](docs/ENDPOINTS.md) catalogue.

#### Added

- **Generated request-param structs (P6a)** — `rake contract:generate` now also
  emits `lib/DhanHQ/contract/params.rb`: one frozen, self-validating struct per
  request-body schema in the vendored contract (26 classes, e.g.
  `DhanHQ::Contract::Params::OrderParams` for `placeorder`/`placesliceorder`).
  Construction fails fast — unknown keys, missing required fields, enum and
  type violations raise `DhanHQ::ValidationError` at the call site, before any
  request leaves the process; IDEs autocomplete the fields. Required lists omit
  the transport-injected `dhanClientId`. Resource methods accept a struct or a
  hash interchangeably (`orders.create(OrderParams.new(...))`), and a
  bindings-driven conformance example enforces that every bound params-taking
  resource method coerces its params — structurally, not by convention.
- **AsyncAPI lifecycle document (P6b)** — `docs/ws_lifecycle.asyncapi.yml`,
  generated from `contracts/dhanhq/ws_protocol.yml` (`rake contract:asyncapi`):
  AsyncAPI 2.6 description of the live feed with servers (feed + 20/200-level
  depth sockets), the JSON command frames (per-family subscribe/unsubscribe and
  the whole-connection disconnect, each stamped with its manifest RequestCode),
  every binary packet carrying its byte layout in `x-dhan-struct`, disconnect
  code examples (805–809), and the `x-dhan-lifecycle` extension (heartbeat
  10s / dead-after-40s silence, 5 connections/user, 5,000 instruments per
  connection). Spec-checked: regeneration must be byte-identical to the
  committed artifact, and every message must match the manifest.
- **`request_payload:` section in `ws_protocol.yml`** — the JSON command-frame
  shape (`instruments` + `requestCode`), verified against the official docs and
  SDKs, so the AsyncAPI document derives command payloads from the manifest.

- **Vendored contracts** — `contracts/dhanhq/live.openapi.json` (47 paths /
  63 operations) and `sandbox.openapi.json` (22 paths / 27 operations),
  unmodified downloads from the `v3/api-docs` endpoints; `contracts/dhanhq/ws_protocol.yml`,
  the byte-level WebSocket wire manifest (packets, request codes, segment enum,
  FMD frame geometry, disconnect codes, limits). Both ship in the gem.
- **Contract overlays** (`contracts/overlays/*.jsonpatch`, RFC 6902) — reviewed
  patches for the vendor spec's defects, applied by `DhanHQ::Contract::SpecLoader`:
  docs-only endpoints (`/profile`, `/RenewToken`, `/instrument/{exchangeSegment}`,
  `/marketfeed/{ltp,ohlc,quote}`, `/optionchain`, `/optionchain/expirylist`),
  rate-limit class annotations on all 71 operations, sandbox behaviour quirks,
  the VCR-verified `GET /profile` on the sandbox host, and the exchangeSegment
  enum reconciled with the official annexure (the vendor spec omits `IDX_I`,
  `NSE_CURRENCY`, `BSE_CURRENCY`).
- **`DhanHQ::Contract::Registry`** — the executable operation index: resolves
  resource calls (verb + path) back to operations, knows each operation's tier,
  param-key style, schemas and sandbox support. `DhanHQ::Contract::Bindings`
  (`bindings.yml`) declares the resource-method → operationId map (57 bindings),
  the intentionally unbound operations and the spec-absent gem endpoints
  (iceberg / TWAP, REVIEW.md M1); the conformance suite enforces completeness
  in all three directions.
- **Schema-derived validation** — `DhanHQ::Contract::SchemaValidator`
  (json_schemer) validates wire payloads against the contract before they are
  sent. `config.validate_requests` defaults to **on** (set
  `DHAN_VALIDATE_REQUESTS=false` to opt out); `config.validate_responses`
  (default off) logs upstream drift instead of raising. Semantic rules
  (lot/tick multiples etc.) remain in the dry-validation contracts.
- **`DhanHQ::WS::Protocol`** — runtime wire knowledge (segment enum,
  subscribe/unsubscribe codes, FMD codes) is now derived from the manifest;
  `spec/dhan_hq/ws/protocol_spec.rb` packs binary fixtures FROM the manifest
  and round-trips them through the real decoders, structurally preventing the
  F1–F7 bug class.
- **Generated artifacts** (`rake contract:generate`, `rake contract:docs`) —
  `lib/DhanHQ/contract/metadata.rb` (frozen schema metadata for all 75
  component schemas) and `docs/ENDPOINTS.md` (endpoint catalogue with tiers,
  param-key styles and sandbox availability).
- **Governance** — `rake contract:refresh` / `contract:check` (vendor spec
  drift as a git diff; CI exit on drift), `rake contract:fuzz` (deterministic
  offline property harness over the sandbox's read-only operations), and the
  scheduled `contract-drift` GitHub workflow.

#### Fixed (contract-driven)

- **Model parity gaps** the contract caught immediately: `Models::Order` now
  exposes `exchange_order_id`; `Models::Holding` exposes `mtf_qty`,
  `mtf_t1_qty` and `last_traded_price` (served by GET /holdings, previously
  dropped on the floor).
- Parameter-key casing in `BaseAPI` is declared per operation in the contract
  (replacing the `path.include?("/marketfeed")` URL sniffing; the sniffed
  strategy remains only as the fallback for unbound legacy paths).
- `dhanClientId` injection moved ahead of contract validation via
  `RequestHelper#with_injected_client_id` (idempotent; `prepare_payload`
  reuses it and wire behaviour is unchanged, including empty-body requests).

## [4.1.1] - 2026-10-11

### Fixed (review against docs.dhanhq.co, dhanhq.co/docs/v2 and the live/sandbox OpenAPI documents)

- **`:hybrid` mode sent the production token to the sandbox host.** Dhan runs sandbox and production with separate credentials and rejects each other's tokens (docs.dhanhq.co, *Sandbox*), so every sandbox-bound request in `:hybrid` was a guaranteed DH-901. New `sandbox_client_id` / `sandbox_access_token` (`DHAN_SANDBOX_CLIENT_ID` / `DHAN_SANDBOX_ACCESS_TOKEN`) are used for every request routed to the sandbox — `access-token` and `client-id` headers, and a body `dhanClientId` that equals the production ID. In `:sandbox` mode they fall back to `client_id` / `access_token`, so existing setups are unaffected; in `:hybrid` they are required and their absence raises `DhanHQ::AuthenticationError` before any I/O.
- **Sandbox-unsupported endpoints now fail fast.** Requests routed to the sandbox for super orders, conditional/multi orders, P&L exit, multi-scrip margin, IP setup, ScanX, market quotes, option chain, rolling options and Global Stocks raise `DhanHQ::SandboxUnsupportedError` instead of returning an opaque 404. They are never redirected to production. The list (`Constants::SANDBOX_UNSUPPORTED_PATH_PREFIXES`) is the set of paths that are absent from the sandbox OpenAPI document and answer 404 on `sandbox.dhan.co`.
- **Full Market Depth (20/200-level) WebSocket never emitted data.** The decoder parsed frames as JSON, while Dhan sends binary packets (12-byte header plus 16-byte `float64`/`uint32`/`uint32` rows, bid and ask as separate stacked packets). Rewritten as a binary decoder; the client merges each instrument's bid and ask packets into one `:depth_update` (`bids`, `asks`, `best_bid`, `best_ask`, `spread`, totals) and emits `:disconnect` for server disconnect packets (code 50).
- **Market depth unsubscribe request code is now 25** (was 24). docs.dhanhq.co gives 25 in both its Annexure and the Full Market Depth page; the older dhanhq.co/docs/v2 Annexure says 24. Not verified against the live feed (it is geo-restricted from CI).
- **200-level depth subscription uses the documented flat format** (`{RequestCode, ExchangeSegment, SecurityId}`), not the 20-level instrument list, and a second instrument on a 200-level connection is refused (one instrument per connection). 20-level connections cap at 50 instruments.
- **`MarketDepth::Client#subscribe(hash)`** subscribed nothing — `Array(hash)` split the instrument hash into key/value pairs.
- **`OrderStatus::INACTIVE`** added; it is in the documented `orderStatus` response enum.

## [4.1.0] - 2026-10-10

### Fixed (full-gem review pass — `ruby-agent-skills` audit)

- **WebSocket feed request codes now match the official Annexure table** (`dhanhq.co/docs/v2/annexure#feed-request-code`). Market feed subscribe per mode: 15/17/21 (was 15 for all three); unsubscribe: 16/18/22 (was 12 for all — 12 is the whole-connection *Disconnect Feed* frame, so per-instrument unsubscribes most plausibly tore down the entire socket). Market depth unsubscribe: 24 (was 12; subscribe stays 23). New spec `spec/dhan_hq/ws/connection_spec.rb` asserts the mapping. **Caveat:** verified against the published table only — `wss://api-feed.dhan.co` is not reachable from the CI environment (geo-block outside India), so a one-constant revert is documented in the review notes if live testing disagrees.
- **Error contract consistency.** `Models::Order#modify/#cancel/#refresh/#slice_order` and `WS::Client` initialization now raise typed errors (`DhanHQ::OrderError`, `DhanHQ::AuthenticationError`) instead of bare `RuntimeError`s, so callers rescuing `DhanHQ::Error` no longer miss guard-clause failures.
- **`RateLimiter` cleanup threads** now spawn only for intervals with finite limits (was 3 immortal threads per tier — 18 in a typical process; now 0 for quote/non-trading, 1 for order/data/global, 3 for option chain). The misleading "matches the published rate-limit table" comment was corrected: values follow this repo's own documented operational limits; per-minute platform caps remain an open question (table unreachable — broken docs site).
- **`WS::Registry`** is now mutex-synchronized (register/unregister/stop_all were unsynchronized) and logs swallowed `stop` failures at debug level instead of rescuing silently.
- **`BaseModel` attribute accessors** are defined once per class instead of two singleton methods per attribute per instance (allocation-heavy on collections). Parameter key style dispatches through `BaseModel.param_key_style` (:title for OptionChain) instead of the fragile `class.name.include?("OptionChain")` check. `validate_attributes` no longer crashes when no contract is declared.
- **Timeouts on the token-endpoint fetch** (`configure_from_token_endpoint` / `configure_from_dashboard`): bounded open/read timeouts matching `Client#build_connection`; previously the only unbounded HTTP path in the gem.
- **Dead code removed:** `BaseAPI#request` (unused private), the commented-out `format_params`/`optionchain_api?` block in `AttributeHelper`, the commented `validate_params!` line in `BaseModel.create`, and the redundant `class Error` reopen in `lib/dhan_hq.rb` (already fully defined in `errors.rb`).
- **Docs:** `docs/ENDPOINTS_AND_SANDBOX.md` no longer documents the non-existent `bin/call_all_endpoints.rb`; the smoke-testing section now references `bin/console`, the sandbox connectivity spec, and `bin/ws_feed_test.rb`. The `DHAN_DEBUG` `puts` in `RateLimiter` was replaced with `DhanHQ.logger&.debug`.

### Added

- **Environment modes — `config.mode = :live | :sandbox | :hybrid` (`DHAN_MODE`)** — one switch that decides which Dhan host every request hits. `:live` (default) keeps today's behaviour; `:sandbox` replaces the old all-or-nothing `sandbox = true` flag; and the new **`:hybrid`** mode is the strategy-rehearsal combination the docs site describes — **live market data + sandbox execution**: market feed, option chain, historical charts, instruments and ScanX keep hitting `https://api.dhan.co/v2` for real prices while orders, positions, funds, statements and the rest of the trading surface hit `https://sandbox.dhan.co/v2`, where orders are validated but never fill.

  ```ruby
  DhanHQ.configure do |config|
    config.mode = :hybrid      # or DHAN_MODE=hybrid
  end

  client.market_feed.ltp("NSE_EQ" => [11536])  # -> api.dhan.co     (live prices)
  client.orders.create(...)                    # -> sandbox.dhan.co (paper execution)
  ```

  - Resolution is per API tier (`order_api`, `data_api`, `quote_api`, `option_chain`, `non_trading_api`, `global_stocks_api`) via `Configuration#base_url_for(api_type)` / `#environment_for(api_type)`; the client rebuilds its Faraday connection when the resolved URL changes, so a mid-flight mode switch takes effect.
  - `config.environment_overrides = { non_trading_api: :live }` (or `DHAN_ENV_OVERRIDES="non_trading_api=live"`) overrides any tier on top of the mode — e.g. keep real fund limits while everything else runs on the sandbox.
  - `sandbox = true` / `DHAN_SANDBOX=true` remain supported aliases for `mode = :sandbox`; `mode` takes precedence when both are given. Unknown modes raise `ArgumentError` at configuration time, not on the first request.
  - Per-client override: `DhanHQ::Client.new(config: shared, mode: :hybrid)` **forks** the configuration rather than mutating the shared/global one, so two clients can run different modes side by side.
  - **Global Stocks (US equities) stays on production in `:hybrid`** on its own `global_stocks_api` rate-limit tier (same limits as order APIs) — `sandbox.dhan.co` does not mirror the `/v2/globalstocks/*` surface.
- **Sandbox-aware LIVE_TRADING gate** — the `ENV["LIVE_TRADING"]` guard now applies only to writes whose effective target is production. Any write routed to the sandbox host (full `:sandbox`, or the trading tiers under `:hybrid`) skips the gate automatically, because no real money can move there. Every order-audit log line now also records `"target":"live"|"sandbox"`, so the audit trail shows which host each attempt fired at.
- **ScanX data API — `client.scanx`** — wraps the four `/v2/data/*` endpoints from the official API surface, each validated by a dry-validation contract, riding the `data_api` tier (live in `:hybrid`):
  - `#company_info` — `POST /v2/data/companyinfo`: company overview, valuation/profitability ratios and shareholding pattern (`metrics: %w[CO RATIOS SHP]`).
  - `#market_movers` — `POST /v2/data/marketmovers`: top options/futures/stocks by OI, volume or price movement; the contract enforces the API's own rule that `expiry` is required for derivative instruments and `universe` for EQUITY.
  - `#news_headlines` — `POST /v2/data/newsheadline`: live news by category/stock (limit 1–50); `dhanClientId` is injected automatically.
  - `#technical_data` — `POST /v2/data/technical`: 24 server-side indicators (SMA/EMA families, RSI_14, MACD_HIST, STOCH, ATR_14, ADX_14, pivots…) computed on the latest closed candle.
  - `/v2/data` joins the `client-id`-header prefixes so ScanX requests authenticate like the other data APIs.

## [4.0.0] - 2026-08-31

### Added

- **Multi-Instance Client Isolation (`DhanHQ::Client.new`)** — run multiple isolated client instances in the same process with separate configurations, credentials, sandbox environments, and rate limiters. Ideal for multi-tenant applications, managing multiple trading accounts concurrently, or comparing sandbox vs. production environments side-by-side.
  ```ruby
  client_a = DhanHQ::Client.new(client_id: "ACC_A", access_token: "TOKEN_A")
  client_b = DhanHQ::Client.new(client_id: "ACC_B", access_token: "TOKEN_B", sandbox: true)

  orders_a = client_a.orders.all
  orders_b = client_b.orders.all
  ```
- **Instance-bound Resource Accessors** — direct accessors on `DhanHQ::Client` instances (`client.orders`, `client.positions`, `client.holdings`, `client.funds`, `client.trades`, `client.market_feed`, `client.option_chain`, `client.historical_data`, `client.forever_orders`, `client.alert_orders`, `client.iceberg_orders`, `client.super_orders`, `client.twap_orders`, `client.statements`, `client.kill_switch`, `client.pnl_exit`, `client.trader_control`, `client.ip_setup`, `client.edis`) bound to that client's configuration and routed to matching rate-limiting tiers (`client_for(API_TYPE)`).
- **Instance-bound WebSocket Helpers** — `client.ws_market_feed`, `client.ws_order_update`, and `client.ws_market_depth` configured automatically with the client instance's credentials and URLs.
- **Keyword Argument Initialization** — `DhanHQ::Client.new` accepts keyword configuration parameters (`dry_run: true`, `sandbox: true`, `client_id: "..."`, `access_token: "..."`) or a `Configuration` instance.
- **Per-Instance Dry-Run Mode** — `DhanHQ::Client.new(dry_run: true)` simulates state-changing writes locally for that instance regardless of the global configuration.
- **Dynamic Model Resource Invalidation** — `DhanHQ.reset_model_resources!` automatically refreshes class-level model caches (`Models::Order.resource`, etc.) whenever `DhanHQ.configure`, `configure_with_env`, `configuration=`, or `reset_configuration!` is invoked.
- **Per-Client Auto Token Management** — `client.enable_auto_token_management!(dhan_client_id: ..., pin: ..., totp_secret: ...)` for automated TOTP-based token lifecycle management per client instance.

## [3.4.0] - 2026-08-15

### Added

- **`DhanHQ::Backtest::Runner`** (with `Trade` and `Result`) — replays a `DhanHQ::Strategy::Base` against historical `OHLCSeries` candles and returns a trade log, a per-bar equity curve, and summary stats (`total_return_pct`, `win_rate`, `max_drawdown_pct`, `num_trades`, `avg_trade_pnl`).

  Both entries and exits fill at the *next* candle's open, never the signal candle's own price — deciding to act on a candle and then filling somewhere inside that same candle is look-ahead bias, since the fill price would have to come from before the candle closed. The equity curve stays flat on the signal bar itself for the same reason: a position isn't marked-to-market until it's actually been filled on the following bar. Risk-rule violations reuse `Strategy::Base#check_risks` rather than a second DSL, and an unclosed position at the end of the dataset is force-closed at the final candle's close. Optional `max_bars_held:` guards against a strategy bug holding a position across the entire dataset.

- **`QUICKSTART.md`** — the 5 most common tasks (install/config, reads, safe order placement, WS streaming, strategy building) in under 50 lines, linked from the README.

- **`DHAN_WS_DEBUG=true`** (`config.ws_debug`) — hex-dumps every raw inbound WebSocket frame at `debug` level before it's parsed, for troubleshooting binary parse errors and dead-but-connected feeds. Off by default, checked before any hex-encoding work so there's no cost when disabled, and capped at 256 bytes per frame (with a `...truncated` marker and the full byte count always logged) so a market-depth feed at tick frequency can't flood the log.

  There isn't a single choke point all raw frames pass through: the market-feed `DhanHQ::WS::Connection` predates `BaseConnection` and has its own `on(:message)` handler, `DhanHQ::WS::Orders::Connection` overrides `BaseConnection#handle_message` entirely without calling `super`, and only `DhanHQ::WS::MarketDepth::Client` goes through `BaseConnection` unmodified. `DhanHQ::WS.debug_frame` is wired into all three so there's one hex-dump implementation, not three that could drift.

- **`rails generate dhanhq:install`** — scaffolds `config/initializers/dhanhq.rb`, an order-placing service object, a Sidekiq market-feed worker, and an ActionCable channel in one command.

- **`DhanHQ::Jobs::PlaceOrderJob`** — an ActiveJob wrapper around `Order.place!`. Uses `discard_on` for `DhanHQ::OrderError`/`DhanHQ::RiskViolation` rather than a manual `rescue`: `discard_on` is handled inside ActiveJob's own `execute`, before an exception would ever reach a queue adapter's own backend-level retry (Sidekiq retries unhandled exceptions by default, independent of ActiveJob's opt-in `retry_on`) — the only adapter-agnostic way to guarantee this non-idempotent write is never silently retried.

### Fixed

- **`docs/RAILS_INTEGRATION.md`'s Sidekiq examples (§5, §6) called `client.wait!`, `client.subscribe(array)`, and `DhanHQ::WS::Client.new(kind: :order_updates)`** — none of which exist. `DhanHQ::WS::Client`/`DhanHQ::WS::Orders::Client` have no blocking wait method at all; `Client#start` spawns a background thread and returns immediately. Replaced with the real API (`DhanHQ::WS.connect`/`DhanHQ::WS::Orders.connect` plus a `connected?`-based liveness loop), guarded by a new spec that locks down the method names these examples call by name.
- **Every runtime dependency except `faraday` had no version floor at all** (`add_dependency "x"`, equivalent to `>= 0` — satisfied by any version ever published). Found while investigating whether the Ruby floor could drop to 3.1 (it can't — see below): forcing a fresh `bundle install` under Ruby 3.1.6 resolved `dry-validation` to `0.4.1`, a 2016-era, pre-`Dry::Validation::Contract` API generation every contract in `lib/DhanHQ/contracts/` is incompatible with — every contract spec failed at `require`-time. Pinning that alone wasn't enough: with `dry-validation` fixed, the same fresh resolve then pulled `activesupport` down to `7.2.3.2` (ActiveSupport 8.x itself requires Ruby ≥ 3.2), and AS 7-vs-8 behavioral differences broke `Agent::ToolRegistry`, `MCP::Server`, and `Risk::Pipeline` — 63 failures with no connection to Ruby version syntax at all.

  All ten now have an explicit floor matching their currently locked major (`activesupport >= 8.0`, `dry-validation ~> 1.0`, and so on) — closing the class of bug, not just the two instances that happened to surface. The `dry-validation` constraint went through two attempts: the first pass in this same release pinned it to `~> 1.11`, which — because `~>` locks to the *last* segment given — actually meant `>= 1.11, < 1.12` and would have silently blocked every future 1.12+ release. Corrected to `~> 1.0`, which excludes the ancient `0.x` line (the actual problem) without capping legitimate 1.x updates.
- **`spec/dhan_hq/contracts/expired_options_data_contract_spec.rb` and `expired_options_data_spec.rb` hardcoded `from_date: "2021-08-02"`**, which is itself now more than 5 years in the past and so failed the contract's own "cannot be more than 5 years ago" rule — the shared fixture failed the exact rule it existed to exercise, cascading into every test merged onto it. Replaced every literal 2021 date with one computed relative to `Date.today`, preserving each test's original intent (span length, ordering, the exact-31-day boundary).

### Investigated, not changed

- **Lowering `required_ruby_version` below `3.2.0`.** This gem's own code needed only two trivial fixes (anonymous `**` keyword forwarding, genuinely 3.2-only syntax — endless methods and anonymous `&` block forwarding, the original suspects, are 3.0+ and 3.1+ respectively and were never the issue). But forcing a fresh dependency resolve under Ruby 3.1.6 — after fixing the `dry-validation` pin above — still forced `activesupport` down to 7.2.3.2 (ActiveSupport 8.x itself requires Ruby ≥ 3.2), and AS 7-vs-8 behavioral differences broke `Agent::ToolRegistry`, `MCP::Server`, and `Risk::Pipeline`: 63 failures across areas with no connection to Ruby version syntax at all. That's a materially larger compatibility surface than a floor bump, so `required_ruby_version` stays `>= 3.2.0`.

## [3.3.0] - 2026-07-26

### Added

- **Bang variants for every write method with a falsy failure contract** — `Order.place!`, `Order#modify!`/`#cancel!`/`#refresh!`, `SuperOrder.create!`/`#modify!`/`#cancel!`, `ForeverOrder.create!`, `IcebergOrder.create!`, `TwapOrder.create!`, `AlertOrder.create!`/`.modify!`, `PnlExit.configure!`/`.stop!`, `MultiOrder.place!`, `GlobalStocks::Order.place!`/`#modify!`/`#cancel!`.

  Each raises `DhanHQ::OrderError` — which descends from `DhanHQ::Error`, so an existing `rescue DhanHQ::Error` handler still catches it — carrying whatever diagnostics the failure held. The non-bang methods are **untouched**: they return exactly what they returned before, so no existing caller changes behaviour.

  This is step one of unifying the write return contracts. Today those contracts disagree: depending on the class and the failure, a rejected write comes back as `nil`, as `false`, or as a `DhanHQ::ErrorObject`, and `AlertOrder.modify` can return either of the first two from the same method. A caller cannot write one error branch. Unifying them outright would be a silent breaking change for dependent applications, because `nil` and `false` are falsy while `ErrorObject` is truthy — every `if result` failure branch in a dependent would quietly invert. So the migration is staged:

  1. **This release** — additive bang variants. Opt in per call site.
  2. **This release** — log a deprecation whenever a non-bang write returns a falsy failure, to find the remaining call sites from dependents' logs.
  3. **4.0.0** — non-bang methods return `ErrorObject` uniformly, gated on step 2 going quiet.

- **Deprecation notices for ambiguous write failures** (step two). When a non-bang write returns `nil`, `false` or a `DhanHQ::ErrorObject`, the SDK now logs once per call site:

  ```
  [DhanHQ] DEPRECATION: DhanHQ::Models::Order.place reported failure as nil. Write
  methods return nil, false or a DhanHQ::ErrorObject inconsistently today and will all
  return DhanHQ::ErrorObject in 4.0.0, which is truthy — an `if result` failure branch
  will invert. Use DhanHQ::Models::Order.place! to get a DhanHQ::OrderError instead...
  ```

  The point is to surface the remaining call sites from dependent applications' logs before 4.0.0 changes any return value. Once per call site per process, not once per failure — a session that rejects hundreds of orders would otherwise produce noise that gets filtered out, defeating the purpose.

  This layer only observes: it never alters a return value and never raises. It is silent on success, silent when reached through a bang variant (those callers have already migrated), and silent when you set `config.warn_on_ambiguous_write_failure = false` / `DHAN_WARN_AMBIGUOUS_WRITE_FAILURE=false`. Defaults to on, because a notice nobody sees finds nothing.

- **`DhanHQ::Concerns::TrackedWrites`** — installs the observation. Uses `prepend` rather than `include`, since the write methods are defined directly on the model classes and an included module would sit behind them in the ancestor chain and never be reached.
- **`DhanHQ::Deprecation`** — once-per-key notice registry, thread-safe, with `warned_keys` and `reset!` for tests.
- **`DhanHQ::WriteResult`** — puts the knowledge of what a write failure looks like in one place (`failure?`, `success?`, `unwrap!`). `BaseModel#save!` now uses it instead of duplicating the same three-way check inline.
- **`DhanHQ::Concerns::BangWrites`** — generates the bang variants by delegating to their non-bang counterparts, so the two cannot drift: no duplicated request building, validation or logging. Generated as a module, so a hand-written `place!` can still override and call `super`.

### Fixed

- **`DhanHQ::MCP` was unreachable on a bare `require "dhan_hq"`.** Same failure as the `DhanHQ::AI` fix earlier in this release: `mcp.rb` defines `DhanHQ::MCP` while Zeitwerk's inflector expected `DhanHQ::Mcp` from the filename, so `DhanHQ::MCP::Server` raised `NameError` unless something had already loaded the file by hand — which only `exe/dhanhq-mcp` and `lib/dhan_hq/mcp.rb` did. Found the same way the `AI` bug was: cross-referencing every `DhanHQ::` constant named in the docs against what actually resolves. Guarded by a new `spec/dhan_hq/zeitwerk_autoload_spec.rb`, which shells out to a subprocess so the check can't be satisfied by another spec having already loaded the file by hand.
- **`lib/DhanHQ/configuration.rb`'s doc comment referenced `DhanHQ::Models::Order.find_by_correlation_id`, which does not exist** — the real method is `.find_by_correlation` (no `_id` suffix). Caught during the same audit.
- A documentation pass across the gem ahead of this release, cross-checking every code example and referenced class/method against the actual codebase:
  - `docs/CONFIGURATION.md`'s resource table named `DhanHQ::Models::Fund` (real class: `Funds`) and `DhanHQ::Models::Ledger` (real class: `LedgerEntry`), and listed `fund_limit`/`margin_calculator` as `Funds` methods — neither exists; the real methods are `Funds.fetch`/`.balance` and `Margin.calculate`/`.calculate_multi`. The table now also covers the resources 3.2.0/3.3.0 added (Iceberg/TWAP/Alert orders, Multi Order, P&L Exit, eDIS, Global Stocks) and lists the `!` write variants.
  - `docs/CONFIGURATION.md` was missing `LIVE_TRADING`, `DHAN_DRY_RUN`, `DHAN_RETRY_WRITES`, `DHAN_AUTO_CORRELATION_ID`, `DHAN_WARN_AMBIGUOUS_WRITE_FAILURE` and `DHAN_MARKET_DEPTH_LEVEL` entirely, and documented `DHAN_LOG_LEVEL` as if the library read it automatically — it doesn't; only the existing `## Logging` snippet wires it up.
  - `skills/dhanhq-ruby/references/portfolio.md`'s eDIS section had the class name miscased (`EDIS` vs. `Edis`), called a nonexistent `.open_browser_for_tpin`, called `.inquiry` instead of `.inquire`, and accessed the (Hash) result via method calls instead of keys.
  - `README.md` called `DhanHQ::Models::Fund.balance` — same class-name typo as above.
  - `docs/RELEASE_GUIDE.md` claimed `Required Ruby: >= 3.1.0`; the gemspec has required `>= 3.2.0` since 3.0.0.
  - `GUIDE.md` had no mention of the bang write variants added in this release; added a short section pointing to the README's fuller treatment.

### Changed

- `BaseModel#save!`'s exception message is now `"<Class>#save failed: <details>"` rather than `"Failed to save the record: <details>"`. The exception class is unchanged (`DhanHQ::Error`), and nothing in the gem, specs or docs asserted the old text.

## [3.2.1] - 2026-07-26

### Fixed

- **Restored the Claude Agent Skill pack to the published gem.** Switching `spec.files` from a reject-list to an allowlist in 3.2.0 stripped 51 MB of junk (a 36 MB core dump and a 17 MB `diagram.html`), but it also dropped `skills/dhanhq-ruby/` — 28 files, 164 KB: `SKILL.md` and its trigger frontmatter, 12 reference guides, 11 examples and 4 helper scripts. That pack is product content, added deliberately in #41. No Ruby code loads it at runtime, so nothing broke and no spec noticed; users installing 3.2.0 simply stopped receiving it. `CODE_OF_CONDUCT.md` and `AGENTS.md` are restored alongside it.

  Unaffected and still shipped throughout: the MCP server (`lib/DhanHQ/mcp/`, `exe/dhanhq-mcp`), the agent tool layer (all 32 tools), the Ruby skills classes (`lib/DhanHQ/skills/`, 11 builtin skills), the risk pipeline and the WebSocket subsystem.

  Gem size: 3.1.0 was 5.9 MB, 3.2.0 was 292 KB, and this is 324 KB. The 20× reduction is real and almost entirely the core dump; the skill pack was collateral.
- **`DhanHQ::AI` was unreachable on a bare `require "dhan_hq"`.** The Zeitwerk inflector had no `ai → AI` acronym, so it looked for `DhanHQ::Ai` while `ai.rb` defines `DhanHQ::AI`; both spellings raised `NameError`. The documented `DhanHQ::AI::PromptHelpers` and `DhanHQ::AI::ContextBuilder` entry points therefore only worked if something had already loaded the file by hand, which only `mcp/server.rb` did. Found while writing the first specs for that module.

### Added

- **`spec/dhan_hq/gem_packaging_spec.rb`** — pins both ends of what ships, since packaging has now failed in both directions. Asserts the entry point, both executables, RBS signatures, Rails initializer, MCP server, agent tool layer, Ruby skills and the Claude Skill pack are all present; asserts the known junk, any crash dump, the spec suite and development config are all absent; and caps the uncompressed payload at 3 MB so a stray binary fails loudly rather than silently adding megabytes to a release.
- First specs for `AI::PromptHelpers` (13 examples), covering portfolio summaries, the risk report's P&L arithmetic — summed across every position, counted only for open ones — and order confirmation rendering. Built on real model instances rather than doubles, because `BaseModel` defines attribute readers per instance and `instance_double` cannot verify them.
- Specs for the lazily-built connection (not opened on construction, memoised, rebuilt on a base-URL change) and for retry exhaustion (transport errors translated, SDK errors re-raised unchanged, reads still retried).

### Changed

- **`Client#with_transient_retry` no longer duplicates its retry branch.** It had two rescue clauses running near-identical backoff-log-sleep-retry logic, differing only in what they raised once retries were spent. Collapsed into one clause, with an `exhausted_error` helper naming the difference: Faraday's transport errors are translated to `DhanHQ::NetworkError` (they are not part of this gem's hierarchy, so a caller rescuing `DhanHQ::Error` would otherwise miss them), while the gem's own errors are re-raised unchanged. Clears the `Lint/DuplicateBranch` pressure on this method.
- **`Client#initialize` no longer opens a connection.** It now establishes state and checks its one invariant; the Faraday connection is built on first use of `#connection` and rebuilt when the configured base URL changes. Behaviour is unchanged for callers — `#connection` is still public and still reflects a sandbox toggle mid-process — but constructing a client does no network setup.
- **`Naming/PredicateMethod` is now scoped by method name instead of by file.** Seven file-level exclusions replaced with `AllowedMethods: [cancel, modify, destroy]` plus `AllowBangMethods: true`.

  These are commands that report whether they succeeded, not predicates — `cancel?` would read as "should I cancel?", which is worse than the name it replaces, so adding `?` aliases would have been the wrong fix. The unambiguous-failure path for them is the bang variant (`cancel!`, `modify!`). Scoping by name rather than by file also means a genuinely mis-named predicate elsewhere in those same files is still caught, and it surfaced a now-redundant inline `rubocop:disable` in `risk/pipeline.rb`.
- `AI::PromptHelpers.portfolio_summary` computed the open-position set twice (`count(&:open?)` then `select(&:open?)`); it now derives it once. Both it and `.risk_report` wrap their collections in `Array()`, so a nil from a failed fetch renders an empty section instead of raising from inside a prompt helper — `funds` was already guarded, the collections were not.

## [3.2.0] - 2026-07-25

### Added

- **Global Stocks (US equities) API** — full coverage of the 11 `/v2/globalstocks/*` endpoints, previously absent:
  - Resources: `Resources::GlobalStocks::Orders` (place/modify/cancel/find/all), `Trades` (all + by security id), `Holdings`, `Funds`, `MarginCalculator` (margin + charge estimate), `MarketStatus`.
  - Models: `Models::GlobalStocks::Order`, `Trade`, `Holding`, `Funds`, `Margin`, `OrderEstimate`, `MarketStatus`.
  - Contracts: `GlobalStocksPlaceOrderContract`, `GlobalStocksModifyOrderContract`, `GlobalStocksEstimatorContract`.
  - Namespaced under `GlobalStocks` so a USD position can never be mistaken for an INR one.
  - Handles the ways this book differs from domestic trading: no exchange segment / product type / validity on orders, float quantities (fractional shares), and the `AMOUNT` notional order type. `MarginCalculator` renders `price`/`quantity` as the strings the API documents while validating them as numbers.
  - Writes are gated by `LIVE_TRADING` and audit-logged like any other order path. `Risk::Pipeline` is deliberately not applied — its checks resolve instruments from the Indian scrip master and encode NSE/BSE rules.
- **Multi Order (basket) endpoint** — `POST /v2/alerts/multi/orders` via `Resources::MultiOrders` and `Models::MultiOrder`, with `MultiOrderContract` enforcing the documented 15-leg cap, unique `sequence` values, and per-leg price/trigger rules. `MultiOrder` exposes `order_ids`, `accepted`, `rejected`, `all_accepted?`, `partially_accepted?` and `for_sequence` so partial acceptance is visible. Previously undocumented as missing — earlier feature tables claimed it was covered.
- **SDK-level dry-run mode** — `config.dry_run` / `DHAN_DRY_RUN=true`. Suppresses every state-changing request (orders, position exits, kill switch, P&L exit, EDIS, IP setup), logs the full payload as `DHAN_DRY_RUN`, and answers order placements with a simulated `DRYRUN-…` order id so caller code paths run to completion. Reads — including read-only POSTs like the option chain, market feed, charts and margin calculators — still hit the API, so a full strategy can be rehearsed against live prices. Complements `Agent::OrderPreview`, which covers a single order.
- **Correlation-id reconciliation** — `config.auto_correlation_id` / `DHAN_AUTO_CORRELATION_ID=true` fills in a `correlationId` (`dhq-<hex>`) on order placements that lack one, so a timed-out placement can be resolved through `GET /v2/orders/external/{correlation-id}`. Off by default because it changes the request body; an explicit correlation id is always preserved.
- **WebSocket lifecycle hooks** — `WS::Client#on` now emits `:open`, `:reconnect`, `:close` and `:error` in addition to `:tick`. `:reconnect` carries `{ attempt:, resubscribed: }` so callers can re-seed derived state (candle builders, caches) after a gap and see which instruments were restored. `WS::Connection` reports transitions through a new `on_event:` callable.
- **WebSocket health checks** — `WS::Client#last_message_at`, `#seconds_since_last_message`, `#healthy?(stale_after: 45)`, `#connected_at`, `#reconnect_count`, `#subscriptions` and `#health`, for monitoring long-running daemons. Frame arrival is tracked separately from socket state because a feed can stay connected while the server stops publishing.
- **9 new agent/MCP tools** (32 total) — `dhan_global_holdings`, `dhan_global_funds`, `dhan_global_orders`, `dhan_global_trades`, `dhan_global_market_status`, `dhan_global_order_estimate` (combines charges and margin in one call), `dhan_global_place_order`, `dhan_global_cancel_order`, `dhan_multi_order`. Each gated by `Agent::Policy` on the same scopes and risk levels as the domestic equivalents.
- **Global Stocks constants** — `Constants::ExchangeSegment::INX_EQ` (kept out of `ALL` so it can never satisfy a domestic order contract) plus `Constants::GlobalStocks` with the `AMOUNT` order type, feed limits (segment code 14, 100 instruments per frame, 5,000 per connection, 5 connections per client), market-status values and feed message codes. `Urls::WS_GLOBAL_STOCKS_FEED` added.
- **Mutating-path constants** — `Constants::MUTATING_PATH_PREFIXES` and `ORDER_PLACEMENT_PATH_PREFIXES` distinguish real writes from the API's several read-only POSTs, driving both dry-run and retry gating.
- **`DhanHQ::WritePaths`** — path taxonomy (`mutating?`, `order_placement?`, `multi_order?`) extracted out of `Client`, which no longer needs to know it.
- **`DhanHQ::DryRun::Simulator` and `::Ledger`** — the dry-run concern extracted out of `Client` as collaborators. The ledger retains up to 500 simulated orders per process, evicting oldest first.
- **`AttributeHelper#deep_camelize_keys`** — recursive key camelization for the endpoints whose bodies nest objects (basket order legs, alert conditions).

### Changed

- **The published gem shrank from 52.5 MB to 1.15 MB.** Four tracked files nobody intended to ship were being published: `core` (a 36.5 MB ELF core dump from an unrelated `light-locker` process), `diagram.html` (17.3 MB), `TAGS`, and `watchlist.csv` — 51.3 MB of the payload, so every `gem install DhanHQ` downloaded a stranger's crash dump. They entered via `f46fde1 "Squashed commit"` and `.gitignore` matched none of them. Removed from tracking, `.gitignore` patterns added, and `spec.files` switched from a reject-list to an explicit allowlist so an unanticipated artifact cannot leak into a release again. All 217 `lib/` files and both executables are unchanged. (The blobs remain in git history; shrinking clones would need a separate history rewrite.)
- **Non-idempotent writes are no longer auto-retried** (behaviour change). `Client#with_transient_retry` previously retried order placement, modification and cancellation on 429s, 5xxs and network timeouts. The DhanHQ API has no idempotency key, so a `POST /v2/orders` that timed out may already have reached the exchange — retrying it could place a second, real order. Transient failures on mutating paths now raise to the caller, who can reconcile before resubmitting. Reads and read-only POSTs keep their exponential backoff unchanged. Set `config.retry_non_idempotent_writes = true` (or `DHAN_RETRY_WRITES=true`) to restore the old behaviour, accepting the duplicate risk.
- `WS::Connection#initialize` accepts an optional `on_event:` keyword; the socket-open handling moved into a `handle_open` method.
- `Configuration` reads boolean env vars through a shared helper, so an empty value is treated as unset rather than false.
- README, ARCHITECTURE.md and CLAUDE.md document the Global Stocks book, basket orders, dry-run mode, write-path safety, and the WebSocket hooks and health API. The "Indian markets only" rule is restated as "DhanHQ v2 API only" — Delta Exchange and other brokers stay out, while DhanHQ's own Global Stocks surface is in scope.
- **`ToolCatalogue.tool` takes keyword arguments.** It had nine positional-and-keyword parameters, so a transposed `scope` and `risk` would have produced a silently mis-gated tool, and it needed an inline `rubocop:disable Metrics/ParameterLists`. Now keyword-only with a `**attributes` splat: an unknown attribute raises rather than half-building a tool, the repeated `version: "1.0.0"` is gone from all 21 definitions in favour of a default, and the inline suppression is removed. Verified by diffing the full 32-tool metadata dump before and after — byte-for-byte identical.
- `.rubocop_todo.yml` excludes `constants.rb` from `Metrics/ModuleLength` (a pure enumeration module whose line count tracks API coverage) and adds `models/global_stocks/order.rb` to the existing `Naming/PredicateMethod` exclusions, matching the domestic `Models::Order`.

### Fixed

- **Basket order legs were sent in snake_case.** `BaseAPI` camelizes only the top level of a payload, so the nested `orders` entries reached the API as `transaction_type`/`exchange_segment`/`security_id` instead of `transactionType`/`exchangeSegment`/`securityId` — every basket order placed through the wrapper would have been rejected. Added `AttributeHelper#deep_camelize_keys` and applied it to the legs. Caught in review by Codex; the original spec only asserted top-level keys, which is why it passed.
- **The same bug pre-existed in alert orders.** `Models::AlertOrder.create` and `.modify` shallow-camelized a payload whose `condition` and `orders` are nested objects, so `AlertCondition` fields (`comparisonType`, `securityId`, `timeFrame`, …) went out snake_cased. Now uses `deep_camelize_keys`.
- **Dry run did not work through the model APIs.** `Models::Order.place` and `GlobalStocks::Order.place` re-fetch after placing, so a simulated `DRYRUN-…` id was carried into a live `GET /v2/orders/{id}` — a real network call and a guaranteed miss. `MultiOrder.place` received no `orders` array and returned an `ErrorObject`. Dry run therefore only worked for direct `Client#request` calls, contradicting the "rehearse a full strategy" claim. Fixed by extracting `DryRun::Simulator` and `DryRun::Ledger`: placements are recorded, reads for a `DRYRUN-` id are replayed locally, and the basket endpoint gets a per-leg response. Caught in review by Codex.
- **`dhanClientId` was never injected for alert orders.** `PAYLOAD_REQUIRES_DHAN_CLIENT_ID_PREFIXES` listed `/alerts/orders`, but `Resources::AlertOrders` uses `HTTP_PATH = "/v2/alerts/orders"`, so the `start_with?` check never matched and the field the API documents as **required** was omitted from every conditional-order payload unless the caller passed it explicitly. Fixed by adding the versioned `/v2/alerts` prefix, which also covers the new multi-order path.
- `DhanHQ::NetworkError` no longer reports "Request failed after 0 retries" when retries are disabled.

### Tests

- 1,052 examples, 0 failures (up from 833); RuboCop clean.
- New specs for the review fixes: nested leg camelization on the wire, dry run completing through `Order.place` / `GlobalStocks::Order.place` / `MultiOrder.place` with zero network calls, `DryRun::Simulator` response shaping and read replay, `DryRun::Ledger` eviction, and `WritePaths` classification (including that read-only POSTs are not treated as writes).
- New specs: Global Stocks resources (orders, holdings, funds, trades, market status, margin calculator) and models (order, holding, funds, trade, market status, margin, order estimate); `MultiOrder`; `Client` dry-run, retry gating and correlation-id behaviour; `WS::Client` lifecycle hooks and health tracking; `WS::Connection` subscription replay and reconnect reporting; agent tool registration and policy enforcement for the new tools; constants and configuration coverage for the new flags and path lists.

## [3.1.0] - 2026-07-20

### Added

- **MCP resources support** — 6 URI-addressable resources (`dhanhq://account/profile`, `funds`, `holdings`, `positions`, `orders`, `dhanhq://market/capabilities`) with `resources/list` and `resources/read`.
- **MCP prompts support** — 5 pre-built AI prompts (`portfolio_summary`, `market_analysis`, `risk_report`, `order_preview`, `suggest_strategy`) with `prompts/list` and `prompts/get`.
- **5 new builtin skills** — `covered_call`, `bull_put_spread`, `bear_call_spread`, `protective_put`, `straddle` (10 total).
- **3 new risk checks** — `PositionLimits` (max 20 concurrent positions), `Concentration` (max 25% per symbol), `MaxLoss` (daily loss limit, default ₹50,000).
- **Extended risk pipeline** — `DhanHQ::Risk::Pipeline` now includes `DAILY_CHECKS` constant and runs all new checks.
- **Risk pipeline wired into all order paths** — `Risk::Pipeline.run!` now fires before every order placement via the `OrderAudit` concern, covering Orders, SuperOrders, ForeverOrders, AlertOrders, TwapOrders, IcebergOrders, and PnL Exit. Instrument resolution failures are handled silently so transient lookup issues never block a valid order.
- **SDK + AI integration docs** — README sections for MCP Server, Skills System, and AI Integration.

### Changed

- `DhanHQ::MCP::Server` now requires `dhan_hq/ai` for prompt generation.
- CI RuboCop step no longer uses `continue-on-error: true`.
- Spec path for risk check specs moved to `spec/dhan_hq/risk/checks/`.
- **`OrderAudit` concern extended** — new `run_risk_checks!(params)` method runs the risk pipeline before order placement, with `trade_type_for` mapping exchange segments to pipeline types. All 7 order resources call it in their `create`/`configure` methods.

### Fixed

- Syntax error in MCP server spec (orphaned `if response["error"]` debug lines removed).
- `[]` method stub pattern in risk check specs (use `receive(:[])` instead of hash double syntax).
- `MaxLoss` spec test data corrected to trigger the daily loss limit correctly.
- All RSpec VerifiedDoubles and MultipleExpectations offenses resolved (0 RuboCop offenses).
- **Position model accessors in risk checks** — replaced `p[:net_quantity]`, `p[:unrealized_profit_loss]`, and `p[:trading_symbol]` hash indexing with real model accessors (`p.net_qty`, `p.unrealized_profit`, `p.trading_symbol`).
- **`ltp` access in all 9 skills** — `instrument.ltp` returns a Float, not a Hash; removed the `ltp[:ltp]` unwrapping pattern.
- **`market_analysis` prompt** — resolves symbol to integer security ID via `Instrument.find` before passing to `MarketFeed.quote`.
- **`OrderAudit#run_risk_checks!` resolved the wrong instrument** — called `Instrument.find(exchange_segment, security_id)`, but `find`'s second argument is a symbol name (e.g. `"RELIANCE"`), not a security ID. Every real order silently failed instrument resolution (`Instrument.find` returned `nil` for a numeric ID), which combined with the surrounding `rescue StandardError; nil` meant **risk checks never ran for any real order placed through any of the 7 order resources**, despite the "wired into all order paths" claim above. Fixed by switching to the new `Instrument.find_by_security_id`. Confirmed live against a real account: `find("NSE_EQ", "2885")` → `nil`; `find_by_security_id("NSE_EQ", "2885")` → resolves RELIANCE correctly.
- **MCP JSON-RPC compliance** — notifications (requests with no `id`) no longer receive a response; dispatch errors preserve the caller's request `id`; error codes now use the correct `-32700`/`-32601`/`-32602`/`-32603` instead of a single generic `-32000`; `protocolVersion` is negotiated against the client's request instead of hardcoded.
- **`dhan_place_order` MCP tool bypassed all risk checks** — now resolves the instrument via `find_by_security_id` and runs `Risk::Pipeline.run!` before calling `Order.place`, same as the resource-level fix above, gated by the same live-write policy checks.
- **Option chain shape mismatch in 8 of 11 skills** — `Instrument#option_chain` returns `{ last_price:, strikes: [{ strike:, call:, put: }] }` (nested Hash), but `iron_condor`, `straddle`, `strangle`, `buy_atm_call`, `covered_call`, `protective_put`, `bull_put_spread`, and `bear_call_spread` were written assuming a flat array of `{ strike:, option_type:, security_id: }` leg-hashes. Every one of these skills raised `NoMethodError`/`TypeError` against the real API; all specs passed anyway because their fixtures invented the same wrong shape. Confirmed broken live, fixed against real NIFTY/RELIANCE option chains (real security IDs verified), all fixtures rewritten to match reality (`spec/support/option_chain_helpers.rb`).
- **MCP tool call could hang indefinitely** — a rate-limited `tools/call` blocked the single-threaded stdio loop with no error surfaced. Added a 15s timeout (`DhanHQ::MCP::Server#tool_call_timeout`) that returns a structured error instead.
- **`dhan_skill_*` tool descriptions** showed the raw Ruby class name (e.g. `"DhanHQ::Skills::Builtin::IronCondor"`) instead of anything useful to an LLM client. Added a `description` class macro to `Skills::Base`; all 11 builtin skills now declare a human-readable one-liner. Verified live via `tools/list`.
- **`Instrument.find`/`.find_by_security_id` could hang for minutes and use gigabytes of RAM** — both built a full `Instrument` model object (each with ~52 `define_singleton_method` calls from `BaseModel#assign_attributes`) for *every row* in the segment before filtering. Confirmed live: a single `find_by_security_id("NSE_EQ", ...)` call ran 98.9% CPU, 4.2GB RSS, and was killed after 3.5 minutes without finishing — `NSE_EQ` has ~219,000 rows. Fixed both methods to scan raw CSV rows and instantiate only the matching one (~9–11s now, down from unbounded). Added dedicated `.find` spec coverage (previously none existed) including a regression guard asserting only one `Instrument` is ever constructed.
- **`correlation_id` accepted up to 30 characters in 4 order contracts** (`PlaceOrderContract`, `ForeverOrderContract`, `IcebergOrderContract`, `TwapOrderContract`), but Dhan's real API caps it at 25 and rejects the **entire order** with a generic, field-agnostic `DH-905` error if exceeded — giving no indication `correlation_id` was the problem. Confirmed live by bisecting the exact boundary (25 chars: success: 26 chars: `DH-905`) against a real sandbox order. All 4 contracts corrected to `max_size?: 25`.
- **`square_off_all`/`square_off_position` never actually found any positions to close** — `SquareOffAll#fetch_positions` called `p[:net_quantity]` on a `Position` model (no `[]` method defined), silently rescued to `0`, and filtered out every real position, always reporting zero exits. `SquareOffPosition#find_position` had the same pattern for `exchange_segment`/`trading_symbol`/`security_id`/`net_quantity`, unguarded by any rescue, so it would raise `NoMethodError` the moment a real position existed. Both bugs were invisible until this session, because no test — unit or live — had ever exercised these skills against a real non-empty `Position.all` result; the unit-test doubles stubbed the same wrong `net_quantity` attribute name the buggy code called. Fixed both to use the real model accessors (`p.net_qty`, `p.exchange_segment`, `p.trading_symbol`, `p.security_id`); fixed both specs' doubles to match. Confirmed live: built a Dhan-API-compatible translation adapter in front of `simulators/paper_exchange` (a real Rails order-matching/fills/positions simulator already in this workspace) so a real order could actually fill (Dhan's own sandbox never executes real fills — confirmed via its docs), producing a genuine non-zero position, then ran `dhan_skill_square_off_all` and `dhan_skill_square_off_position` through the full MCP-gated path against it: both correctly found the position and closed it (`net_qty` 4→0 and 2→0 respectively) with a real `SUCCESS` response.

### Known Limitations

Verified live against a real Dhan account (live-scoped and sandbox), a real independent MCP client, and — for the two paths sandbox cannot simulate (real fills, real position closure) — a purpose-built Dhan-API-compatible adapter in front of `simulators/paper_exchange`'s real order-matching engine.

- **Live-tested, all of it, including the full write path**: core REST client, MCP protocol layer, all 11 skills' intent-building, WebSocket streaming, and — end to end — `dhan_place_order`, `dhan_cancel_order`, `dhan_skill_square_off_all`, and `dhan_skill_square_off_position`, each through the actual MCP-gated path (instrument resolution → full risk pipeline → audit log → real order execution). Dhan's sandbox itself only validates request/response plumbing and never executes a real fill (confirmed via Dhan's own docs: "the sandbox behaves like the live API but does not execute real orders") — fills were exercised against `simulators/paper_exchange`'s real matching engine via a throwaway adapter (not shipped, not committed) instead.
- **`Concentration`/`PositionLimits`/`MaxLoss` risk checks** have only been observed against zero-position, zero-or-low-balance accounts, and against `paper_exchange`'s simulated position (a single small equity position). Their math is unit-tested; behavior against a large, multi-symbol real portfolio has not been observed.
- **The sandbox environment's instrument/security-ID catalog appears disconnected from the production instrument master** — a real production TCS security ID (`532540`, resolved via `Instrument.find`) was rejected by the sandbox's matching engine (`DH-906: Transaction has Failed`), while an ID from a prior sandbox test (`11536`) validated successfully. Anyone testing against sandbox should resolve security IDs from sandbox-originated data (e.g. prior order history), not the live instrument master.
- **`release.yml`'s GitHub Release gem-asset upload** has not fired end-to-end — no tag has been pushed since the fix landed.
- **v3.1.0 is not tagged** — CHANGELOG reflects work in progress on `main`, not a cut release.
- **Nothing from this session is committed.**

---

## [3.0.0] - 2026-05-19

### Breaking Changes

- **TA and analysis modules are now opt-in**. `require 'dhan_hq'` no longer auto-loads `DhanHQ::Analysis::*` or `TA::*`. Explicitly require what you need:
  ```ruby
  require 'dhan_hq/analysis'  # OptionsBuyingAdvisor, MultiTimeframeAnalyzer
  require 'dhan_hq/ta'        # TA::TechnicalAnalysis, TA::Fetcher, TA::Candles
  ```

### Changed

- `exe/DhanHQ` now correctly uses `require "dhan_hq"` (was the old `require "DhanHQ"`).
- Gemspec file renamed back to `DhanHQ.gemspec` (was `dhan_hq.gemspec`) to resolve RubyGems "too similar" name collision and ensure successful push of the `DhanHQ` gem.
- Updated all `Gemfile` references and installation docs to use `DhanHQ` while maintaining `require 'dhan_hq'` for standard Ruby conventions.
- SimpleCov now tracks all `lib/**/*.rb` files (was models-only).

---

## [2.8.0] - 2026-03-21

### Added

- **Complete SDK Documentation Overhaul**: Added high-level guides and structured learning paths for Ruby developers:
  - `BEST_WAY_TO_USE_DHAN_API_IN_RUBY.md`: Strategic advice for Ruby-centric integration.
  - `BUILD_A_TRADING_BOT_WITH_RUBY_AND_DHAN.md`: Step-by-step tutorial for algo trading.
  - `HOW_TO_USE_DHAN_API_WITH_RUBY.md`: Foundational guide for REST and WebSocket.
  - `DHAN_API_RUBY_EXAMPLES.md`: Curated collection of common API patterns.
  - `DHAN_WEBSOCKET_RUBY_GUIDE.md`: Deep dive into real-time market data and order updates.
  - `DHAN_RUBY_QA.md`: Troubleshooting and frequently asked questions.
- **Production-Ready Examples**:
  - `examples/basic_trading_bot.rb`: Skeleton for a strategy-based bot.
  - `examples/options_watchlist.rb`: Script for monitoring specific option strikes.
  - `examples/portfolio_monitor.rb`: Live tracker for PnL and position status.
- **Architectural Visualization**: New `docs/architecture-overview.svg` illustrating the SDK's layered design (Models, Resources, Contracts, WebSocket).

### Changed

- **SDK Positioning**: Updated `README.md` and `DhanHQ.gemspec` to reflect the SDK's status as a "production-grade Ruby SDK for Dhan API v2" with an emphasis on algo trading, portfolio monitoring, and resilient streaming.
- **Documentation Refinement**: Improved clarity and navigation in `CONFIGURATION.md`, `LIVE_ORDER_UPDATES.md`, `RAILS_INTEGRATION.md`, `TESTING_GUIDE.md`, `TROUBLESHOOTING.md`, and `WEBSOCKET_INTEGRATION.md`.

---

## [2.7.0] - 2026-03-17

### Added

- **Order audit logging across all order types**: Every order submission (regular, super, forever/GTT, and alert orders) now emits a WARN-level structured JSON log line capturing: event type, public IPv4/IPv6, hostname, runtime environment, `security_id`, `correlation_id`, and UTC timestamp. Log output example:
  ```json
  {"event":"DHAN_ORDER_ATTEMPT","hostname":"DESKTOP-SHUBHAM","env":"production","ipv4":"122.171.22.40","ipv6":"2401:4900:...","security_id":"11536","correlation_id":"SCALPER_7af1","timestamp":"2026-03-17T06:45:22Z"}
  ```
  Events logged: `DHAN_ORDER_ATTEMPT`, `DHAN_ORDER_MODIFY_ATTEMPT`, `DHAN_ORDER_SLICING_ATTEMPT`, `DHAN_SUPER_ORDER_ATTEMPT`, `DHAN_SUPER_ORDER_MODIFY_ATTEMPT`, `DHAN_SUPER_ORDER_CANCEL_ATTEMPT`, `DHAN_FOREVER_ORDER_ATTEMPT`, `DHAN_FOREVER_ORDER_MODIFY_ATTEMPT`, `DHAN_FOREVER_ORDER_CANCEL_ATTEMPT`, `DHAN_ALERT_ORDER_ATTEMPT`, `DHAN_ALERT_ORDER_MODIFY_ATTEMPT`, `DHAN_ALERT_ORDER_DELETE_ATTEMPT`, `DHAN_PNL_EXIT_CONFIGURE_ATTEMPT`, `DHAN_PNL_EXIT_STOP_ATTEMPT`.
- **`DhanHQ::Concerns::OrderAudit`**: Shared concern providing `log_order_context` and `ensure_live_trading!` — included in `Resources::Orders`, `Resources::SuperOrders`, `Resources::ForeverOrders`, `Resources::AlertOrders`, and `Resources::PnlExit`.
- **`DhanHQ::Utils::NetworkInspector`**: New utility class that resolves the machine's public IPv4 (via api.ipify.org), IPv6 (via api64.ipify.org), hostname (`Socket.gethostname`), and runtime environment (`RAILS_ENV` / `RACK_ENV` / `APP_ENV`). IP lookups are memoized for the process lifetime; call `NetworkInspector.reset_cache!` to refresh.
- **Live trading guard**: All mutating order/trader-control calls require `ENV["LIVE_TRADING"]="true"`. Guarded methods:
  - `Resources::Orders#create`, `#update`, `#slicing`, `#cancel`
  - `Resources::SuperOrders#create`, `#update`, `#cancel`
  - `Resources::ForeverOrders#create`, `#update`, `#cancel`
  - `Resources::AlertOrders#create`, `#update`, `#delete`
  - `Resources::PnlExit#configure`, `#stop`
- **`DhanHQ::LiveTradingDisabledError`**: New error class raised when the live trading guard fires.
- **Correlation ID prefix convention**: Recommended per-app correlation ID prefixes for instant source identification in the Dhan orderbook (e.g. `SCALPER_7af1`, `TRADER_3bc9`). See README.

### Changed

- **`Resources::Orders`**: `#create`, `#update`, `#slicing`, `#cancel` log order context and enforce the live trading guard.
- **`Resources::SuperOrders`**: `#create`, `#update`, `#cancel` log order context and enforce the live trading guard.
- **`Resources::ForeverOrders`**: `#create`, `#update`, `#cancel` log order context and enforce the live trading guard.
- **`Resources::AlertOrders`**: `#create`, `#update`, `#delete` log order context and enforce the live trading guard; `#delete` added.
- **`Resources::PnlExit`**: `#configure` and `#stop` use `OrderAudit` (guard + audit log).

### Breaking

- **`ENV["LIVE_TRADING"]` required for all order/trader-control mutations**: Any call that creates, updates, cancels, or deletes orders (or configures/stops PnL exit) now raises `LiveTradingDisabledError` unless `ENV["LIVE_TRADING"]="true"`. Affects `Resources::Orders`, `Resources::SuperOrders`, `Resources::ForeverOrders`, `Resources::AlertOrders`, `Resources::PnlExit`, and the corresponding model wrappers. Set `LIVE_TRADING=true` in production and `LIVE_TRADING=false` (or omit) in development/test.

---

## [2.6.3] - 2026-03-14

### Added

- **Constants::Urls**: All canonical Dhan API/auth/WebSocket URLs in one place (`REST_API_BASE`, `SANDBOX_API_BASE`, `AUTH_BASE`, `WS_MARKET_FEED`, `WS_ORDER_UPDATE`, `WS_DEPTH_20`, `WS_DEPTH_200`, `INSTRUMENT_CSV_*`, `DOCS`, `ORIGIN`). Configuration, Auth, and WS defaults now use these constants.
- **Order modification limit enforcement**: `Order#modify` enforces Dhan’s 25-modifications-per-order cap per instance; the 26th modify raises `DhanHQ::ModificationLimitError` and does not call the API. Count is in-process only (fresh `find` resets it).
- **DhanHQ::ModificationLimitError**: New error class for the 25-per-order limit (rescuable).
- **API error payload on exceptions**: Raised API errors now expose the full response body as `error.response_body` (e.g. `errorCode`, `errorMessage`, and any future keys like `errors` or `details`). Useful for logging and debugging.
- **DH-905 message hint**: For `InputExceptionError` (DH-905), the exception message now includes a note that the Dhan API does not return which field failed, and to check required params and value types for the endpoint.
- **Kill switch status validation**: `Resources::KillSwitch#update(status)` and `Models::KillSwitch.update(status)` now validate that `status` is `ACTIVATE` or `DEACTIVATE` (case-insensitive); invalid values raise `DhanHQ::ValidationError` before the request.
- **Super order cancel leg validation**: `Resources::SuperOrders#cancel(order_id, leg_name)` validates `leg_name` against the API path enum (`ENTRY_LEG`, `STOP_LOSS_LEG`, `TARGET_LEG`); invalid values raise `DhanHQ::ValidationError`.

### Changed

- **SliceOrderContract**: Aligned with Dhan v2 orders doc — `amoTime` now allows `PRE_OPEN`; validity restricted to `DAY`/`IOC`; product type restricted to `CNC`/`INTRADAY`/`MARGIN`/`MTF`; `correlationId` max length 30 (was 25).
- **Order#modify** YARD: Documented modification limit and `ModificationLimitError`.
- **Error#initialize**: `DhanHQ::Error` now accepts an optional `response_body:` keyword argument so API-raised errors can carry the parsed response. Subclasses unchanged; `raise ErrorClass, "msg"` still works.
- **ResponseHelper**: When the API returns extra keys (`errors`, `details`, `validationErrors`), they are appended to the exception message. DH-905 errors include the endpoint hint above.
- **Margin contracts**: `MarginCalculatorContract` and `MultiScripMarginCalcRequestContract` accept optional `orderType` (per OpenAPI; some accounts require it). `Margin` model and `bin/test_all` margin payloads send `order_type: LIMIT` when `DHAN_TEST_MARGIN=true`.
- **bin/test_all**: Fixed `ArgumentError: wrong number of arguments (given 1, expected 0)` by invoking endpoint lambdas with no arguments inside `Timeout.timeout` (the timeout block receives the duration). Refactored `endpoint_list` for RuboCop Metrics/AbcSize; optional read endpoints (forever order by id, PnL exit, margin) are skipped unless `DHAN_TEST_FOREVER_ORDER_ID`, `DHAN_TEST_PNL_EXIT=true`, or `DHAN_TEST_MARGIN=true` are set.

### Fixed

- **bin/test_all**: All 30 read endpoints now run successfully by default (26 called, 4 optional); margin/PnL/forever-by-id no longer fail when fixtures are missing.

### Removed

- **docs/DHAN_V2_GAPS.md**: Removed; path/behavior alignment remains in `docs/API_VERIFICATION.md`.

---

## [2.6.2] - 2026-03-07

### Changed

- **Release from main** after merging add-sandbox-support. Includes sandbox REST base URL, `ensure_configuration!`, payload non-mutation, Rakefile/VCR fixes, and docs. Full feature list is under [2.6.0](#260---2026-03-06); 2.6.0 and 2.6.1 are already on RubyGems.

---

## [2.6.1] - 2026-03-07

### Changed

- **Version bump**: 2.6.0 was already published on RubyGems; no code changes. Use this version for the same 2.6.0 feature set (sandbox, contracts, Order methods, stability fixes).

---

## [2.6.0] - 2026-03-06

### Sandbox & configuration

- **Sandbox environment**: `DhanHQ.configuration.sandbox` (or `ENV["DHAN_SANDBOX"]=true`) switches REST base URL to `https://sandbox.dhan.co/v2`. Only `GET /v2/profile` and `GET /v2/fundlimit` are verified on sandbox; other REST endpoints are unverified. See `docs/ENDPOINTS_AND_SANDBOX.md`.
- **WebSocket**: Sandbox does **not** support WebSocket. Order updates, market feed, and market depth always use production URLs regardless of `sandbox`; no sandbox WS URLs are published.
- **Env-only bootstrap**: `DhanHQ.ensure_configuration!` ensures configuration exists (from ENV when nil). Called automatically in `Client#initialize` so apps using only `DHAN_CLIENT_ID` / `DHAN_ACCESS_TOKEN` work without calling `configure_with_env`.

### Fixed

- **Payload mutation**: `prepare_payload` no longer mutates the caller's hash when injecting `dhanClientId` for DATA APIs; uses a duplicate so frozen or reused hashes are safe.
- **VCR**: Removed erroneous `/v2/v2/` market feed cassette entries (404 responses).
- **Rakefile**: Single RuboCop task; removed redundant `rubocop:fix` / `rubocop:fix_all` and deprecated `--auto-correct-all` flag.

### Added

- **docs/ENDPOINTS_AND_SANDBOX.md**: Lists all REST/WebSocket endpoints, sandbox behavior, and endpoints verified vs not supported on sandbox.

### Fixed (API docs alignment)

- **Kill Switch**: Manage API now uses query parameter per [dhanhq.co/docs/v2/traders-control](https://dhanhq.co/docs/v2/traders-control/). `Resources::KillSwitch#update(status)` sends `POST /v2/killswitch?killSwitchStatus=ACTIVATE` (or `DEACTIVATE`) with no body. `Models::KillSwitch.update("ACTIVATE")` / `.activate` / `.deactivate` unchanged.
- **IP Setup**: Set/Modify now send required API fields. `Resources::IPSetup#set` and `#update` accept `ip:`, `ip_flag: "PRIMARY"` (or `"SECONDARY"`), and optional `dhan_client_id:` (defaults from `DhanHQ.configuration.client_id`). See [dhanhq.co/docs/v2/authentication/#setup-static-ip](https://dhanhq.co/docs/v2/authentication/#setup-static-ip).
- **Alert Orders (Conditional Trigger)**: Condition now requires `exchange_segment`, `exp_date`, and `frequency` per [dhanhq.co/docs/v2/conditional-trigger](https://dhanhq.co/docs/v2/conditional-trigger/). `time_frame` is required when `comparison_type` starts with `TECHNICAL`. `AlertOrderContract` and all examples updated.

### Breaking changes

- **AlertOrder.create / AlertOrderContract**: Contract expects nested structure (see 2.5.0). Condition hash must include `exchange_segment`, `exp_date`, and `frequency`; for `comparison_type` starting with `TECHNICAL`, `time_frame` is required. See GUIDE.md and [conditional-trigger](https://dhanhq.co/docs/v2/conditional-trigger/).
- **Resources::KillSwitch#update**: Signature is now `update(status)` (string). Use `update("ACTIVATE")` or `Models::KillSwitch.activate` / `.deactivate`, unchanged.
- **AlertOrderContract** — expected payload shape:

```ruby
AlertOrderContract.new.call(
  condition: {
    exchange_segment:  "NSE_EQ",
    security_id:       "11536",
    comparison_type:   "PRICE_WITH_VALUE",
    operator:          "GREATER_THAN",
    exp_date:          "2026-12-31",
    frequency:         "ONCE"
  },
  orders: [
    { transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "INTRADAY", order_type: "MARKET", security_id: "11536", quantity: 5, validity: "DAY" }
  ]
)
```

### Added

#### Order Model — New Public Methods
- **`Order#destroy` / `#delete`**: Cancels an order via `DELETE /v2/orders/{id}`. Returns `true` if the API confirms `CANCELLED` status, `false` otherwise. `#delete` is an alias.
- **`Order#slice_order(params)`**: Splits a large order into multiple legs to exceed freeze-limit quantities on F&O instruments via `POST /v2/slicing`. Delegates to `Resources::Orders#slicing`.
- **`Order#save`**: ActiveRecord-style save — places a new order for new records, modifies existing records. Returns `true`/`false`.
- **`Order.place` — `dhan_client_id` auto-injection**: If `dhan_client_id` is not passed in params, it is automatically read from `DhanHQ.configuration.client_id`. Existing code that passes `dhan_client_id` explicitly continues to work unchanged.

#### Contract Hardening
- **`OrderContract`** (base for `PlaceOrderContract` and `ModifyOrderContract`) now enforces:
  - `LIMIT` orders require `price`; `MARKET` orders reject `price`
  - `STOP_LOSS` / `STOP_LOSS_MARKET` require `trigger_price`
  - Stop-loss price relationships: BUY requires `trigger_price >= price`; SELL requires `trigger_price <= price`
  - Bracket Order (BO): both `bo_profit_value` and `bo_stop_loss_value` required; directional profit/loss relationship validated
  - `disclosed_quantity` cannot exceed 30% of `quantity`
  - `amo_time` required when `after_market_order: true`
  - Lot-size and tick-size enforcement when `instrument_meta` is provided
  - Segment-based product restrictions (CNC equity-only, BO/CO currency restrictions)
- **`ModifyOrderContract`**: Requires at least one modifiable field; inherits all `OrderContract` business rules.
- **New contracts**: `EdisContract`, `UserIpContract`, `PnlBasedExitContract`, `MultiScripMarginCalcContract`, `SliceOrderContract`.

#### Infrastructure
- **`ApiResponseHandler` concern** (`lib/DhanHQ/models/concerns/api_response_handler.rb`): Shared module for uniform API response handling, attribute merging, and structured logging. Included in `Order` and `ForeverOrder`.
- **Global Constants Enforcement**: Replaced all hardcoded API strings with `DhanHQ::Constants` across the repository. Built a custom RuboCop cop (`RuboCop::Cop::DhanHQ::UseConstants`) that strictly enforces typed constants instead of loose strings for robust API payloads.
- **Constants Documentation**: Added `docs/CONSTANTS_REFERENCE.md` detailing all SDK constants (e.g., `ExchangeSegment`, `ProductType`, `OrderType`, etc.).

### Changed
- Replaced 160+ hardcoded usages of strings like `"NSE_EQ"` and `"BUY"` with `DhanHQ::Constants::ExchangeSegment::NSE_EQ` and `DhanHQ::Constants::TransactionType::BUY`.
- Added `NO_HOLDINGS` (value `"DH-1111"`) to `TradingErrorCode`.
- `PlaceOrderContract` refactored to inherit from `OrderContract`, eliminating duplicated validation logic. Derivative-specific fields (`drv_expiry_date`, `drv_option_type`, `drv_strike_price`) remain on `PlaceOrderContract`.
- `Resources::Orders` now fetches optional instrument metadata (lot size, tick size) to pass into contract validation.

---

## [2.5.0] - 2026-02-21

### Added

#### New Endpoints — Full Dhan API v2 Parity
- **Exit All Positions**: `DhanHQ::Models::Position.exit_all!` — emergency closure of all positions and cancellation of all open orders via `DELETE /v2/positions`. Resource method: `DhanHQ::Resources::Positions#exit_all`.
- **Kill Switch Status**: `DhanHQ::Models::KillSwitch.status` — query current kill switch state via `GET /v2/killswitch`. Resource method: `DhanHQ::Resources::KillSwitch#status`.
- **P&L Based Exit**: New `DhanHQ::Models::PnlExit` model and `DhanHQ::Resources::PnlExit` resource for automatic profit/loss-based position exit:
  - `PnlExit.configure(profit_value:, loss_value:, product_type:, enable_kill_switch:)` — `POST /v2/pnlExit`
  - `PnlExit.stop` — `DELETE /v2/pnlExit`
  - `PnlExit.status` — `GET /v2/pnlExit`
- **Multi-Order Margin Calculator**: `DhanHQ::Models::Margin.calculate_multi` — batch margin calculation with hedge benefit across multiple instruments via `POST /v2/margincalculator/multi`. Resource method: `DhanHQ::Resources::MarginCalculator#calculate_multi`.
- **EDIS Model**: New `DhanHQ::Models::Edis` wrapping existing `DhanHQ::Resources::Edis` with ORM-style class methods:
  - `Edis.generate_tpin`, `Edis.generate_form`, `Edis.generate_bulk_form`, `Edis.inquire`
- **Postback Payload Parser**: New `DhanHQ::Models::Postback` utility model for parsing Dhan webhook payloads:
  - `Postback.parse(json_or_hash)` — accepts JSON string or Hash
  - Status predicates: `traded?`, `rejected?`, `pending?`, `cancelled?`
- **AlertOrder Modify**: Explicit `DhanHQ::Models::AlertOrder.modify(alert_id, params)` class method for updating conditional triggers with better discoverability.

#### Tests
- **28 new specs** across 7 files (442 total, 0 failures):
  - `spec/dhan_hq/models/pnl_exit_spec.rb` — configure, stop, status, defaults, nil handling
  - `spec/dhan_hq/models/edis_spec.rb` — generate_tpin, generate_form, bulk_form, inquire
  - `spec/dhan_hq/models/postback_spec.rb` — JSON/Hash parsing, snake_case support, status predicates
  - Updated: `kill_switch_spec.rb`, `positions_spec.rb`, `margin_spec.rb`, `alert_order_spec.rb`

### Changed
- **README.md**: Updated Key Features to reflect full API v2 parity including P&L Exit, Postback parser, and EDIS model.
- **Bundler**: Updated `BUNDLED WITH` to latest version, eliminating platform constant re-definition warnings.

### Notes
- **Backward Compatible**: All changes are additive — no existing APIs or method signatures changed.
- **Full API v2 Parity**: The gem now covers every endpoint documented at [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/).

---

## [2.4.0] - 2026-02-18

### Added
- Support for Individual TOTP-based access token generation
- `DhanHQ::Auth.generate_access_token`
- `DhanHQ::Auth.generate_totp`

### Updated
- RenewToken now uses POST (aligned with Dhan API behavior)
- Improved error handling for authentication APIs

### Notes
- TOTP tokens can now be programmatically regenerated without browser login
- RenewToken still applies only to web-generated tokens

---

## [2.3.0] - 2026-02-04

### Added
- **Alert Orders**: `DhanHQ::Resources::AlertOrders` (BaseResource) and `DhanHQ::Models::AlertOrder` with full CRUD. Endpoints: GET/POST `/alerts/orders`, GET/PUT/DELETE `/alerts/orders/{id}` (per API docs). Validation via `DhanHQ::Contracts::AlertOrderContract`.
- **IP Setup**: `DhanHQ::Resources::IPSetup` (resource-only). Methods: `current` (GET `/ip/getIP`), `set(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)` (POST `/ip/setIP`), `update(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)` (PUT `/ip/modifyIP`). Body includes `dhanClientId` (default from config) and `ipFlag` per API docs.
- **Trader Control (Kill Switch)**: `DhanHQ::Resources::TraderControl` (resource-only). Methods: `status` (GET `/trader-control`), `enable` (POST action ENABLE), `disable` (POST action DISABLE). `DhanHQ::Resources::KillSwitch` and `DhanHQ::Models::KillSwitch` remain for backward compatibility.
- **docs/API_VERIFICATION.md**: Documents alignment with [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/) and [api.dhan.co/v2](https://api.dhan.co/v2/#/) for EDIS, Alert Orders, IP Setup.

### Changed
- **EDIS**: Resource-only, aligned with [dhanhq.co/docs/v2/edis](https://dhanhq.co/docs/v2/edis/). Use `DhanHQ::Resources::Edis`: `form(params)` (POST `/edis/form`; isin, qty, exchange, segment, bulk), `bulk_form(params)` (POST `/edis/bulkform`), `tpin` (GET `/edis/tpin`), `inquire(isin)` (GET `/edis/inquire/{isin}`).
- **BaseResource**: Fixed path building: `all`/`find`/`create`/`update`/`delete` now pass relative endpoints (`""`, `"/#{id}"`) so the base path is not doubled.

---

## [2.2.2] - 2026-01-31

### Contracts (date validation)

- **from_date / to_date**: `from_date` must be strictly before `to_date` and must be a valid trading date (no weekend). `to_date` may be any date after `from_date` (format YYYY-MM-DD). Applied in `HistoricalDataContract`, `TradeHistoryContract`, and `ExpiredOptionsDataContract`.
- **HistoricalDataContract**: Added trading-day check for `from_date` and `from_date < to_date`; inherits `BaseContract`.

### Specs & tooling

- **Specs**: Base model, expired options, trade, and historical data specs updated to use weekday dates and expect `from_date must be before to_date`; VCR cassette `trade_history.yml` updated for new date.
- **RuboCop**: RSpec/ExampleLength in expired options contract spec fixed via `next_weekday` helper.

---

## [2.2.1] - 2026-01-31

### Authentication

- **RenewToken API**: Added `DhanHQ::Auth.renew_token(access_token, client_id, base_url: nil)` to refresh web-generated access tokens (24h validity). Calls GET `/v2/RenewToken` with `access-token` and `dhanClientId` headers; returns response hash with indifferent access (e.g. `accessToken`, `expiryTime`). Use in `access_token_provider` or `on_token_expired` to refresh and store the new token. Only valid for tokens generated from Dhan Web (not API key flow).
- **Dhan auth scope**: Documented that the gem does **not** implement API key/secret consent or Partner consent flows; apps obtain tokens via Dhan Web, API key OAuth, or Partner flow and pass them to the gem. See [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md).

### Documentation

- **docs/AUTHENTICATION.md**: Added “How you get the token (Dhan’s responsibility)” (Individual: Web token, RenewToken, API key; Partner: consent flow) and “RenewToken (web-generated tokens only)” with `DhanHQ::Auth.renew_token` usage and example. “See also” updated for GUIDE, rails_integration, TESTING_GUIDE, CHANGELOG 2.2.0/2.2.1.
- **README.md**: Note under Dynamic access token for RenewToken via `DhanHQ::Auth.renew_token` and that API key/Partner flows are implemented in the app.
- **GUIDE.md**: “Dynamic access token” section extended with RenewToken (`DhanHQ::Auth.renew_token`) and note that API key/Partner flows are in the app.
- **docs/TESTING_GUIDE.md**: Optional config comment for RenewToken and pointer to AUTHENTICATION.md (API key/Partner in app).
- **docs/RAILS_INTEGRATION.md**: “Dynamic access token” section extended with RenewToken (web-generated tokens) and link to AUTHENTICATION.md.
- **docs/WEBSOCKET_INTEGRATION.md**, **docs/LIVE_ORDER_UPDATES.md**: Notes updated for dynamic token, RenewToken, and API key/Partner in app.
- **docs/STANDALONE_RUBY_WEBSOCKET_INTEGRATION.md**, **docs/RAILS_WEBSOCKET_INTEGRATION.md**: Configuration section updated with RenewToken and AUTHENTICATION.md link.

### CI / Release

- **Release workflow**: Aligned with ollama-client: tag-based release (`on: push: tags: v*`), validate tag vs gem version, use `GEM_HOST_API_KEY` for RubyGems push (no credentials file), single retry with OTP. Removed GitHub Release step.
- **RELEASING.md**, **docs/RELEASE_GUIDE.md**: Updated to describe tag-only publish and `GEM_HOST_API_KEY`; removed references to “Create GitHub Release” and “Run tests” in release job.

### Fixes

- **RuboCop**: Layout/EmptyLineAfterGuardClause — added blank line after guard clauses in Configuration, WS client, market depth client, orders connection. Style/NilLambda — `-> { nil }` → `-> {}` in configuration_spec. RSpec/InstanceVariable — replaced `@token_call_count` and `@hook_called`/`@hook_error` with `let(:token_call_count)`, `let(:token_provider)`, `let(:hook_state)` in client_spec auth-failure examples.
- **CI**: Gemfile.lock updated for path gem version (DhanHQ 2.2.1) so `bundle install` in frozen mode succeeds.

### Added

- **lib/DhanHQ/auth.rb**: New module with `Auth.renew_token` for Dhan RenewToken API.

---

## [2.2.0] - 2026-01-31

### Authentication & token handling

- **Dynamic access token resolution**: Token can be resolved at request time via `config.access_token_provider` (Proc/lambda). When set, the provider is called on each request; when not set, the gem falls back to `config.access_token`. No memoization — token is fetched per request for production-safe rotation.
- **Auto-expiry detection**: API error code **807** (token expired) now raises `DhanHQ::TokenExpiredError` so callers can handle expiry explicitly. Error codes 401, 807, 809, and 808 are treated as auth failures for retry logic.
- **Retry-on-401 with token re-fetch**: When the API returns 401 or token-expired (InvalidAuthenticationError, InvalidTokenError, TokenExpiredError, AuthenticationFailedError) and `config.access_token_provider` is set, the client retries the request **once** after the next token resolution (provider is called again). No separate “refresh” call — the provider is the source of the new token.
- **Optional `on_token_expired` hook**: `config.on_token_expired` (callable) is invoked when an auth failure triggers a retry, before the retry is performed. Use for logging or refreshing token in your store; the retry then uses the token from `access_token_provider`.
- **`DhanHQ::AuthenticationError`**: New error for local auth failures (missing token or provider returned nil/empty). API-level auth errors continue to use `InvalidAuthenticationError` / `InvalidTokenError` / `TokenExpiredError` as before.

### Configuration

- **New**: `config.access_token_provider` — callable that returns the access token string at request time.
- **New**: `config.on_token_expired` — optional callable invoked when 401/token-expired triggers a retry (only when `access_token_provider` is set).
- **New**: `config.resolved_access_token` — returns the token to use (from provider or static `access_token`); raises `AuthenticationError` if provider returns nil/empty.

### Errors

- **New**: `DhanHQ::AuthenticationError` — raised when token cannot be resolved (missing config or provider returned nil/empty).
- **New**: `DhanHQ::TokenExpiredError` — raised when API returns error code 807 (token expired). Mapped from `DHAN_ERROR_MAPPING["807"]`.

### Tests

- **WebMock specs for auth failures**: `spec/dhan_hq/client_spec.rb` — contexts for 401, 403, 807, retry-on-401 with provider, retry then raise when 401 persists, and `on_token_expired` hook.
- **Response helper**: Spec for 807 → TokenExpiredError in `spec/dhan_hq/helpers/response_helper_spec.rb`.

### Documentation

- **README.md**: New subsection “Dynamic access token (optional)” under Configuration.
- **GUIDE.md**: Short “Dynamic access token” note and link to docs/AUTHENTICATION.md.
- **docs/AUTHENTICATION.md**: New doc for static vs dynamic token, retry-on-401, and auth-related errors.
- **docs/TESTING_GUIDE.md**: Optional access_token_provider / on_token_expired in config examples.
- **docs/RAILS_INTEGRATION.md**: “Dynamic access token (optional)” with Rails initializer example.
- **docs/WEBSOCKET_INTEGRATION.md**, **docs/LIVE_ORDER_UPDATES.md**: Pointer to docs/AUTHENTICATION.md for dynamic token.

### Backward compatibility

- **Non-breaking**: Existing `config.access_token = "static-token"` continues to work. `access_token_provider` is optional. Safe to release as a **minor** version bump.

---

## [2.1.11] - 2025-01-27

This release includes comprehensive bug fixes, security improvements, and reliability enhancements. All changes are **backward compatible** - no breaking changes.

### 🔴 Critical Fixes

#### Thread Safety & Concurrency
- **Rate limiter race condition**: Fixed thread safety issue where cleanup threads modified shared state without synchronization. Added mutex protection and graceful shutdown mechanism.
- **WebSocket thread safety**: Fixed callback iteration race condition by creating frozen snapshots to prevent modification during event emission.

#### Error Handling & Validation
- **Client credential validation**: Moved validation to request time (in `build_headers`) rather than initialization, maintaining backward compatibility while ensuring credentials are validated before API calls.
- **WebSocket error handling**: Added proper cleanup and state reset on exceptions, improved logging with backtraces for better debugging.
- **Price field validation**: Added comprehensive validation for all float fields (price, trigger_price, bo_profit_value, bo_stop_loss_value, drv_strike_price) to reject NaN, Infinity, and values exceeding reasonable bounds (1,000,000,000).

### 🟠 High Priority Fixes

#### Memory Management
- **Order tracker memory leak**: Fixed unbounded memory growth in WebSocket order tracker by implementing automatic cleanup with configurable limits:
  - Maximum tracked orders: 10,000 (configurable via `DHAN_WS_MAX_TRACKED_ORDERS`)
  - Maximum order age: 7 days (configurable via `DHAN_WS_MAX_ORDER_AGE`)
  - Automatic cleanup thread runs hourly

#### Reliability & Error Handling
- **JSON parse error handling**: Improved error handling for invalid JSON responses. Empty strings return empty hash (backward compatible), but truly invalid JSON now raises `DataError` with detailed logging.
- **Timeout configuration**: Added configurable timeouts to prevent requests from hanging indefinitely:
  - Connection timeout: 10s (configurable via `DHAN_CONNECT_TIMEOUT`)
  - Read timeout: 30s (configurable via `DHAN_READ_TIMEOUT`)
  - Write timeout: 30s (configurable via `DHAN_WRITE_TIMEOUT`)
- **Retry logic**: Added automatic retry with exponential backoff for transient errors (RateLimitError, InternalServerError, NetworkError, timeouts). Default: 3 retries with exponential backoff (1s, 2s, 4s, capped at 30s).

### 🟡 Medium Priority Fixes

#### Code Quality & Reliability
- **Order modification validation**: Added warning logs for invalid order states (TRADED, CANCELLED, EXPIRED, CLOSED) but still attempts API call - API handles final validation (backward compatible).
- **Error mapping**: Added logging for unmapped error codes to aid investigation and debugging.
- **Rate limiter cleanup**: Added `shutdown()` method to gracefully stop cleanup threads and prevent resource leaks.
- **Order operation logging**: Added structured logging for order placement and modification operations to aid debugging.

### 🔵 Low Priority Fixes

#### Code Quality
- **Code deduplication**: Made `delete` delegate to `destroy`, removing duplicate code.
- **Type consistency**: Added `.to_s` conversion for `id` method to ensure consistent string return type.
- **Response format logging**: Added logging for unexpected response formats in collection parsing to help identify API changes.

### ✅ API Compliance

- **Header validation**: Validates required headers (`access_token`, `client_id` for DATA APIs) before making requests, providing clear error messages.
- **202 Accepted status**: Properly handles `202 Accepted` status code for async operations (e.g., position conversion).

### ➕ Added

#### Configuration Options
- **Timeout configuration** via environment variables:
  - `DHAN_CONNECT_TIMEOUT` - Connection timeout in seconds (default: 10)
  - `DHAN_READ_TIMEOUT` - Read timeout in seconds (default: 30)
  - `DHAN_WRITE_TIMEOUT` - Write timeout in seconds (default: 30)
- **WebSocket order tracker configuration** via environment variables:
  - `DHAN_WS_MAX_TRACKED_ORDERS` - Maximum orders to track (default: 10,000)
  - `DHAN_WS_MAX_ORDER_AGE` - Maximum order age in seconds (default: 604,800 = 7 days)

#### Test Coverage
- `spec/dhan_hq/contracts/place_order_contract_spec.rb` - Comprehensive price validation tests
- `spec/dhan_hq/helpers/response_helper_spec.rb` - JSON parsing and error handling tests
- `spec/dhan_hq/ws/orders/client_spec.rb` - Order tracker cleanup and thread safety tests
- Updated existing specs to cover new functionality and improvements

### 🔄 Changed

- **Error handling**: Improved error messages and logging throughout the codebase
- **Thread safety**: Enhanced thread safety in rate limiter and WebSocket clients
- **Memory management**: Order tracker now automatically cleans up old orders
- **JSON parsing**: Invalid JSON now raises `DataError` with logging (empty strings still return empty hash for backward compatibility)

### 🗑️ Removed

- `lib/DhanHQ/contracts/modify_order_contract_copy.rb` - Removed unused duplicate file

### 📝 Notes

- **Backward Compatibility**: All changes maintain 100% backward compatibility. No breaking changes.
- **API Compliance**: All fixes align with official API documentation at https://api.dhan.co/v2/#/
- **Performance**: Memory leak fixes and cleanup mechanisms improve long-running application stability
- **Reliability**: Retry logic and improved error handling increase resilience to transient failures

## [2.1.10] - 2025-11-11

### Fixed
- Expired Options Data routing: send `client-id` header for `/v2/charts/rollingoption` by adding `/v2/charts/` to data API prefixes.
- Correct `HTTP_PATH` for `ExpiredOptionsData` resource to `/v2/charts`.
- Prevent false validation failures by allowing up to 31-day ranges (to_date non-inclusive).

### Changed
- Align `ExpiredOptionsData` contract with broker docs:
  - `interval` accepted as String (e.g., "1", "5", "15", "25", "60").
  - `security_id` validated as Integer.
- Input normalization for `ExpiredOptionsData.fetch`:
  - Coerce convertible types (`interval`, `security_id`, `expiry_code`).
  - Uppercase enums and `strike`, normalize `required_data` to downcased unique list.
- Improved examples and YARD docs to reflect the above.

## [2.1.9] - 2025-01-31

### Added
- **Comprehensive YARD documentation**: Added complete YARD documentation across all model classes with detailed parameter specifications, return types, and examples:
  - `DhanHQ::Models::Edis` - EDIS form, bulk form, TPIN, and inquiry methods documented
  - `DhanHQ::Models::ExpiredOptionsData` - Expired options data fetching with strike analysis helpers
  - `DhanHQ::Models::ForeverOrder` - Forever Order (GTT) creation, modification, and cancellation
  - `DhanHQ::Models::Funds` - Account fund information retrieval
  - `DhanHQ::Models::HistoricalData` - Daily and intraday historical candle data fetching
  - `DhanHQ::Models::Holding` - Portfolio holdings retrieval
  - `DhanHQ::Models::Margin` - Margin calculation for orders
  - `DhanHQ::Models::MarketFeed` - LTP, OHLC, and quote data fetching
  - `DhanHQ::Models::OptionChain` - Option chain data and expiry list fetching
  - `DhanHQ::Models::Order` - Order placement, modification, cancellation, and slicing
  - `DhanHQ::Models::Position` - Position management and conversion
  - `DhanHQ::Models::SuperOrder` - Multi-leg super order management
  - `DhanHQ::Models::Trade` - Trade book, order trades, and historical trades
  - `DhanHQ::Models::Profile` - User profile and account information
  - `DhanHQ::Models::KillSwitch` - Kill switch activation and deactivation
- All documentation includes:
  - Complete parameter documentation with types, descriptions, and valid values
  - Comprehensive return type specifications with response structure details
  - Multiple practical examples for each method
  - Response field normalization (snake_case) documentation
  - Error handling documentation with `@raise` tags
  - Special notes and prerequisites where applicable

### Changed
- **Documentation standards**: All model documentation now follows YARD best practices with:
  - Properly indented `@option` tags for better readability
  - Consistent use of YARD hash syntax for parameter and return types
  - Detailed response structure documentation with field types and descriptions
  - Clarified that `dhan_client_id` must be explicitly provided (not auto-injected) where applicable

## [2.1.8] - 2025-10-30

### Fixed
- Correctly map `underlying_seg` for option chain APIs:
  - Index instruments use `IDX_I`.
  - Stocks map to `NSE_FNO` or `BSE_FNO` based on the instrument's exchange.
- Implemented via `underlying_segment_for_options` in `DhanHQ::Models::InstrumentHelpers` and applied to `expiry_list` and `option_chain`.

## [2.1.7] - 2025-01-28

### Added
- **Instrument instance methods**: Added convenience methods to Instrument model for accessing market feed, historical data, and option chain data
  - `instrument.ltp` - Fetches last traded price using `DhanHQ::Models::MarketFeed.ltp`
  - `instrument.ohlc` - Fetches OHLC data using `DhanHQ::Models::MarketFeed.ohlc`
  - `instrument.quote` - Fetches full quote depth using `DhanHQ::Models::MarketFeed.quote`
  - `instrument.daily(from_date:, to_date:, **options)` - Fetches daily historical data using `DhanHQ::Models::HistoricalData.daily`
  - `instrument.intraday(from_date:, to_date:, interval:, **options)` - Fetches intraday historical data using `DhanHQ::Models::HistoricalData.intraday`
  - `instrument.expiry_list` - Fetches expiry list using `DhanHQ::Models::OptionChain.fetch_expiry_list`
  - `instrument.option_chain(expiry:)` - Fetches option chain using `DhanHQ::Models::OptionChain.fetch`
  - All methods automatically use the instrument's `security_id`, `exchange_segment`, and `instrument` attributes
- **InstrumentHelpers module**: Created reusable module to provide these convenience methods

### Changed
- Align Super Order documentation across README, README1, and GUIDE with the latest API contract (place, modify, cancel, list).
- Normalise remaining documentation examples to snake_case, including order update WebSocket callbacks and kill switch response guidance.

## [2.1.5] - 2025-01-27

### ⚠️ BREAKING CHANGES
- **Changed require statement**: `require 'DhanHQ'` → `require 'dhan_hq'`
  - This affects all Ruby files that require the gem
  - Update all `require 'DhanHQ'` statements to `require 'dhan_hq'` in your codebase
  - The gem name remains `DhanHQ` in your Gemfile, only the require statement changes

### Added
- **OptionChain validation**: Added proper parameter validation for `OptionChain.fetch` and `OptionChain.fetch_expiry_list` methods
  - `OptionChain.fetch` requires `underlying_scrip`, `underlying_seg`, and `expiry` parameters
  - `OptionChain.fetch_expiry_list` requires only `underlying_scrip` and `underlying_seg` parameters
  - Validates exchange segments against `%w[IDX_I NSE_FNO BSE_FNO MCX_FO]`
  - Validates expiry format as `YYYY-MM-DD` and ensures it's a valid date

### Fixed
- **RuboCop compliance**: Fixed all RuboCop offenses (179 → 0 offenses)
- **Documentation**: Updated all documentation examples to use `require 'dhan_hq'`
- **Documentation**: Correct Super Order examples to use snake_case parameters for `DhanHQ::Models` helpers
- **Documentation**: Normalise Super Order path placeholders and response fields to snake_case for consistency
- **Documentation**: Clarified that model helpers auto-inject `dhan_client_id`, removing the need to add it manually in Ruby payloads
- **Code quality**: Added comprehensive validation tests for OptionChain methods

### Changed
- **File structure**: Renamed main library file from `lib/DhanHQ.rb` to `lib/dhan_hq.rb` for better Ruby conventions
- **Require paths**: Updated all internal require statements to use snake_case naming

## [2.1.0] - 2025-09-20

- Add REST coverage for EDIS (`/edis/form`, `/edis/bulkform`, `/edis/tpin`, `/edis/inquire/{isin}`) and the account kill-switch endpoint.
- Harden client-side validations: enforce `SliceOrderContract` via `Order#slice_order`, `MarginCalculatorContract` before `/v2/margincalculator`, and `PositionConversionContract` prior to `/v2/positions/convert`.
- Adjust rate limiting to match the latest broker quotas, including a dedicated quote bucket.
- Improve Forever Order routing (`/v2/forever/orders`) and expose the user profile helper.

## [2.0.3] - 2025-09-18

- Refresh GUIDE.md to align with current DhanHQ contracts, models, and data services.

## [2.0.2] - 2025-09-16

- Add `DhanHQ::WS::Client#connected?` to expose connection state.

## [0.1.0] - 2025-01-23

- Initial release
