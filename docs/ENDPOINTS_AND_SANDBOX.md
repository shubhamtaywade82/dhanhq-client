# DhanHQ gem — Endpoints, environments and sandbox support

## Environments: `:live`, `:sandbox`, `:hybrid`

`DhanHQ.configuration.mode` (or `DHAN_MODE`) selects which host each REST request hits.
The legacy `sandbox = true` / `DHAN_SANDBOX=true` remains an alias for `mode = :sandbox`.

| Mode       | Data tiers (`data_api`, `quote_api`, `option_chain`) | Trading/account tiers (`order_api`, `non_trading_api`) | Global Stocks (`global_stocks_api`) |
| ---------- | ---------------------------------------------------- | ------------------------------------------------------ | ----------------------------------- |
| `:live` (default) | `api.dhan.co/v2`                              | `api.dhan.co/v2`                                        | `api.dhan.co/v2`                    |
| `:sandbox` | `sandbox.dhan.co/v2`                                  | `sandbox.dhan.co/v2`                                    | `sandbox.dhan.co/v2`                |
| `:hybrid`  | `api.dhan.co/v2` — live prices                        | `sandbox.dhan.co/v2` — paper execution                  | `api.dhan.co/v2` (sandbox does not mirror it) |

`hybrid` exists for strategy rehearsal: read live market data, place orders against the
sandbox host. Per-tier overrides (`environment_overrides`) win over the mode defaults —
for example keeping the real fund limits while everything else runs on the sandbox:

```ruby
DhanHQ.configure do |c|
  c.mode = :hybrid
  c.environment_overrides = { non_trading_api: :live }  # or String form: "non_trading_api=live"
end
```

Per-client override (forks the config, never mutates the shared one):

```ruby
client = DhanHQ::Client.new(config: shared_config, mode: :hybrid)
```

Resolution order for any request: explicit `config.base_url` (if set, it wins for every
request) → `environment_overrides[tier]` → mode default for that tier.

### Credentials per environment

Dhan treats sandbox and production as separate environments with separate credentials
("Do not reuse production tokens for sandbox requests or sandbox tokens for production
requests" — docs.dhanhq.co, *Sandbox*). The gem therefore resolves credentials per tier
alongside the host:

| Request routed to | `access-token` header | `client-id` header / body `dhanClientId` |
| ----------------- | --------------------- | ---------------------------------------- |
| production        | `access_token` (`DHAN_ACCESS_TOKEN`) | `client_id` (`DHAN_CLIENT_ID`) |
| sandbox           | `sandbox_access_token` (`DHAN_SANDBOX_ACCESS_TOKEN`) | `sandbox_client_id` (`DHAN_SANDBOX_CLIENT_ID`) |

A body `dhanClientId` equal to the production `client_id` (models fill it in) is rewritten
to the sandbox ID on sandbox-bound requests; an explicitly different ID is left alone. In
`:sandbox` mode the sandbox pair falls back to the primary pair; in `:hybrid` (or with a
tier overridden to the sandbox) missing sandbox credentials raise
`DhanHQ::AuthenticationError` before any I/O.

## Sandbox behavior

- **Sandbox does NOT execute real order fills/matching.** Confirmed both via Dhan's own docs ("the sandbox behaves like the live API but does not execute real orders") and empirically: a `MARKET` order placed on sandbox validates and returns a real `orderId`, but stays at `PENDING` indefinitely — it never transitions to `TRADED`, even after 24+ seconds of polling. Use sandbox to validate request/response plumbing (auth, payload shape, error codes), not to test fill, cancel, or square-off behavior.
- **REST:** every wrapped REST endpoint listed below is sent to the host its tier resolves to (see the mode table above) — `:sandbox` sends everything to `https://sandbox.dhan.co/v2`, `:hybrid` splits data vs trading.
- **Sandbox does NOT support WebSocket.** Order updates, market feed, and market depth are **production-only**. The gem always uses production WebSocket URLs regardless of the mode. There are no sandbox WebSocket endpoints in the Dhan v2 API; do not rely on sandbox for real-time streams. Under `:hybrid` the order-update stream therefore reports your **real** account, not sandbox orders.
- **LIVE_TRADING gate** is relaxed automatically for any write whose effective target is the sandbox host (no real money at risk). Production-targeted writes still require `ENV["LIVE_TRADING"]="true"`. Order audit log lines carry `"target":"live"|"sandbox"`.
- **Auth endpoints** (`DhanHQ::Auth`) do **not** follow the mode. They always call:
  - `https://auth.dhan.co` — token generation
  - `https://api.dhan.co/v2` — token renewal
  So token generation/renewal always hit production; only data/order REST calls follow the mode.

---

## Sandbox endpoint support

Source: the sandbox's own OpenAPI document (`https://sandbox.dhan.co/v2/v3/api-docs`), the
*Sandbox* page on docs.dhanhq.co, and an unauthenticated probe of each path (an existing
route answers 401/400, a missing one 404).

| Status | Endpoints |
|--------|-----------|
| **Served by the sandbox** | `/orders` (place, modify, cancel, book, by id, by correlation id), `/orders/slicing`, `/trades`, `/trades/{order-id}`, `/holdings`, `/positions`, `/positions/convert`, `POST /killswitch`, `/edis/tpin`, `/edis/form`, `/edis/bulkform`, `/edis/inquire/{isin}`, `/fundlimit`, `POST /margincalculator`, `/ledger`, `/trades/{from}/{to}/{page}`, `/charts/historical`, `/charts/intraday`, `/forever/orders` (in the sandbox OpenAPI document, not on the docs page), `/profile` (route exists; not documented) |
| **Not served — 404** (gem raises `DhanHQ::SandboxUnsupportedError`) | `/super/orders`, `/alerts/orders`, `/alerts/multi/orders`, `/pnlExit`, `/margincalculator/multi`, `/ip/*`, `/marketfeed/*`, `/optionchain`, `/optionchain/expirylist`, `/charts/rollingoption`, `/data/*` (ScanX), `/globalstocks/*` |
| **Unclear** | `GET /killswitch` and `DELETE /positions` answer 400 rather than 404 but are absent from both sandbox sources. Iceberg/TWAP (`/v2/orders/iceberg`, `/v2/orders/twap`) are not in any Dhan documentation; the gateway answers any `/v2/orders/*` path, so a probe cannot tell. |
| **Not supported** | All WebSocket endpoints (order updates, market feed, market depth). Production only. |

The deny-list lives in `DhanHQ::Constants::SANDBOX_UNSUPPORTED_PATH_PREFIXES`. In
`:hybrid` mode a blocked request is **never** redirected to production — that would turn a
paper order into a real one.

---

## REST endpoints integrated in the gem

Paths are as built by the gem (HTTP_PATH + endpoint). Base URL is resolved per tier — see the mode table above.

| Resource / model           | Path(s)                                      | Methods   | API type        |
|----------------------------|----------------------------------------------|-----------|-----------------|
| **Profile**                | `/v2/profile`                                | GET       | non_trading_api |
| **Funds**                  | `/v2/fundlimit`                              | GET       | order_api       |
| **Statements**             | `/v2/ledger`, `/v2/trades/{from}/{to}/{page}`| GET       | non_trading_api |
| **Orders**                 | `/v2/orders`, `/v2/orders/{id}`, `/v2/orders/external/{correlation_id}`, `/v2/orders/slicing` | GET, POST, PUT, DELETE | order_api |
| **Positions**              | `/v2/positions`, `/v2/positions/convert`     | GET, POST, DELETE | order_api |
| **Holdings**               | `/v2/holdings`                               | GET       | order_api       |
| **Trades**                 | `/v2/trades`, `/v2/trades/{order_id}`        | GET       | order_api       |
| **Forever orders**         | `/v2/forever/orders`, `/v2/forever/orders/{id}` | GET, POST, PUT, DELETE | order_api |
| **Super orders**           | `/v2/super/orders`, `/v2/super/orders/{id}`, leg delete | GET, POST, PUT, DELETE | order_api |
| **Kill switch**            | `/v2/killswitch`                             | GET, POST | order_api       |
| **Trader control**         | `/trader-control`                            | GET, POST | order_api       |
| **IP setup**               | `/ip/getIP`, `/ip/setIP`, `/ip/modifyIP`     | GET, POST, PUT | order_api |
| **EDIS**                   | `/edis/tpin`, `/edis/form`, `/edis/bulkform`, `/edis/inquire/{isin}` | GET, POST | order_api |
| **Alert orders**           | `/alerts/orders`                             | GET, POST, PUT, DELETE | order_api |
| **PnL exit**               | `/v2/pnlExit`                                | GET, POST, DELETE | order_api |
| **Margin calculator**      | `/v2/margincalculator`, `/v2/margincalculator/multi` | POST      | order_api       |
| **Instruments**            | `/v2/instrument/{segment}` (redirect to CSV) | GET       | data_api        |
| **Market feed**            | `/v2/marketfeed/ltp`, `/v2/marketfeed/ohlc`, `/v2/marketfeed/quote` | POST      | data_api / quote_api |
| **Option chain**           | `/v2/optionchain`, `/v2/optionchain/expirylist` | POST      | data_api        |
| **Historical data**        | `/v2/charts/historical`, `/v2/charts/intraday` | POST      | data_api        |
| **Expired options data**   | `/v2/charts/rollingoption`                   | POST      | data_api        |
| **ScanX — company info**   | `/v2/data/companyinfo`                       | POST      | data_api        |
| **ScanX — market movers**  | `/v2/data/marketmovers`                      | POST      | data_api        |
| **ScanX — news**           | `/v2/data/newsheadline`                      | POST      | data_api        |
| **ScanX — technicals**     | `/v2/data/technical`                         | POST      | data_api        |
| **Global Stocks**          | `/v2/globalstocks/orders`, `/v2/globalstocks/holdings`, `/v2/globalstocks/fundlimit`, `/v2/globalstocks/trades`, `/v2/globalstocks/marketstatus`, `/v2/globalstocks/margincalculator`, `/v2/globalstocks/transEstimate` | GET/POST/PUT/DELETE | global_stocks_api |

---

## Auth (outside main client base URL)

| Purpose           | URL / path                     | Method |
|-------------------|--------------------------------|--------|
| Generate token    | `https://auth.dhan.co/app/generateAccessToken` | POST   |
| Renew token       | `https://api.dhan.co/v2/RenewToken`           | GET    |

These are **not** mode-aware; they always use the URLs above.

---

## WebSocket endpoints (production only; sandbox not supported)

| Purpose        | URL |
|----------------|-----|
| Order updates  | `wss://api-order-update.dhan.co` |
| Market feed    | `wss://api-feed.dhan.co` |
| Market depth   | `wss://depth-api-feed.dhan.co/twentydepth` |

**Sandbox:** Dhan sandbox does **not** provide WebSocket services. These endpoints are production-only. The gem never switches WS URLs based on the mode; you can still override via `DhanHQ.configuration.ws_order_url`, `ws_market_feed_url`, `ws_market_depth_url`, or env vars `DHAN_WS_ORDER_URL`, `DHAN_WS_MARKET_FEED_URL`, `DHAN_WS_MARKET_DEPTH_URL` if you have a different production URL.

---

## Summary

- **Modes:** `:live` (default — everything on production), `:sandbox` (everything on `sandbox.dhan.co`), `:hybrid` (data tiers live, trading tiers sandbox, Global Stocks live). Set via `config.mode`, `DHAN_MODE`, or the legacy `config.sandbox` / `DHAN_SANDBOX`.
- **Verified on sandbox:** only `GET /v2/profile` and `GET /v2/fundlimit` — see "Sandbox: verified vs not working / unverified" above.
- **LIVE_TRADING:** required only for writes that target production; sandbox-targeted writes are exempt.
- **Auth:** Token generation and renewal always use production hosts.
- **WebSockets:** Sandbox does **not** support WebSocket. Order updates, market feed, and market depth always use production URLs; the gem does not publish or use any sandbox WebSocket URLs.

## Smoke testing

There is no shipped call-all-endpoints script (an earlier revision of this page
referenced `bin/call_all_endpoints.rb`, which does not exist in the repo). Use
what is actually here:

```bash
bin/console                  # IRB with the gem preloaded — try client.profile.get,
                              # client.market_feed.ltp(...), client.fundlimit.get ...
bundle exec rspec spec/dhan_hq/sandbox_connectivity_spec.rb   # guarded sandbox probes
bin/ws_feed_test.rb          # live market-feed smoke test (production WS only)
```

Requires `DHAN_CLIENT_ID` and `DHAN_ACCESS_TOKEN`. Optional: `DHAN_MODE=hybrid`
(or `DHAN_SANDBOX=true`).
