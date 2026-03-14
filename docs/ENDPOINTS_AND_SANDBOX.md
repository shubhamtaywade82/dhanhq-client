# DhanHQ gem — Endpoints and sandbox support

## Sandbox behavior

- **REST:** When `DhanHQ.configuration.sandbox == true` (or `ENV["DHAN_SANDBOX"]=true`), the client uses `https://sandbox.dhan.co/v2` as the base URL for **all** requests that go through `DhanHQ::Client`. Every wrapped REST endpoint listed below is therefore **sent** to the sandbox host when sandbox is enabled.
- **Sandbox does NOT support WebSocket.** Order updates, market feed, and market depth are **production-only**. The gem always uses production WebSocket URLs regardless of the `sandbox` setting. There are no sandbox WebSocket endpoints in the Dhan v2 API; do not rely on sandbox for real-time streams.
- **Auth endpoints** (`DhanHQ::Auth`) do **not** use sandbox. They always call:
  - `https://auth.dhan.co` — token generation
  - `https://api.dhan.co/v2` — token renewal  
  So token generation/renewal always hit production; only data/order REST calls follow the sandbox flag.

---

## Sandbox: verified vs not working / unverified

| Status    | Endpoints |
|-----------|-----------|
| **Verified on sandbox** (gem specs) | `GET /v2/profile`, `GET /v2/fundlimit` |
| **Sandbox connectivity spec** | `spec/dhan_hq/sandbox_connectivity_spec.rb` — uses VCR `record: :new_episodes`. In CI, use committed cassettes or skip without sandbox credentials; locally, run with `VCR_RECORD=new_episodes` and sandbox credentials to record. |
| **Not supported in sandbox** | All WebSocket endpoints (order updates, market feed, market depth). Use production only. |
| **Not verified on sandbox** | All other REST endpoints below. They may fail, return differently, or be unavailable in sandbox. Use Dhan documentation or manual testing before relying on them in sandbox. |

**REST endpoints not verified / may not work on sandbox** (only profile and funds are verified):

- `/v2/ledger`, `/v2/trades/{from}/{to}/{page}` (statements)
- `/v2/orders` (all order CRUD, slicing, external)
- `/v2/positions`, `/v2/positions/convert`
- `/v2/holdings`
- `/v2/trades`, `/v2/trades/{order_id}`
- `/v2/forever/orders` (all)
- `/v2/super/orders` (all)
- `/v2/killswitch`
- `/trader-control`
- `/ip/getIP`, `/ip/setIP`, `/ip/modifyIP`
- `/edis/tpin`, `/edis/form`, `/edis/bulkform`, `/edis/inquire/{isin}`
- `/alerts/orders`
- `/v2/pnlExit`
- `/v2/margincalculator`, `/v2/margincalculator/multi`
- `/v2/instrument/{segment}`
- `/v2/marketfeed/ltp`, `/v2/marketfeed/ohlc`, `/v2/marketfeed/quote`
- `/v2/optionchain`, `/v2/optionchain/expirylist`
- `/v2/charts/historical`, `/v2/charts/intraday`, `/v2/charts/rollingoption`

---

## REST endpoints integrated in the gem

Paths are as built by the gem (HTTP_PATH + endpoint). Base URL is either `https://api.dhan.co/v2` (production) or `https://sandbox.dhan.co/v2` (sandbox).

| Resource / model           | Path(s)                                      | Methods   | API type        |
|---------------------------|----------------------------------------------|-----------|-----------------|
| **Profile**               | `/v2/profile`                               | GET       | non_trading_api |
| **Funds**                 | `/v2/fundlimit`                              | GET       | non_trading_api |
| **Statements**            | `/v2/ledger`, `/v2/trades/{from}/{to}/{page}`| GET       | non_trading_api |
| **Orders**                | `/v2/orders`, `/v2/orders/{id}`, `/v2/orders/external/{correlation_id}`, `/v2/orders/slicing` | GET, POST, PUT, DELETE | order_api |
| **Positions**             | `/v2/positions`, `/v2/positions/convert`     | GET, POST, DELETE | order_api |
| **Holdings**              | `/v2/holdings`                               | GET       | order_api       |
| **Trades**                | `/v2/trades`, `/v2/trades/{order_id}`        | GET       | order_api       |
| **Forever orders**        | `/v2/forever/orders`, `/v2/forever/orders/{id}` | GET, POST, PUT, DELETE | order_api |
| **Super orders**          | `/v2/super/orders`, `/v2/super/orders/{id}`, leg delete | GET, POST, PUT, DELETE | order_api |
| **Kill switch**           | `/v2/killswitch`                             | GET, POST | order_api       |
| **Trader control**        | `/trader-control`                            | GET, POST | order_api       |
| **IP setup**              | `/ip/getIP`, `/ip/setIP`, `/ip/modifyIP`     | GET, POST, PUT | order_api |
| **EDIS**                  | `/edis/tpin`, `/edis/form`, `/edis/bulkform`, `/edis/inquire/{isin}` | GET, POST | order_api |
| **Alert orders**          | `/alerts/orders`                             | GET, POST, PUT, DELETE | order_api |
| **PnL exit**              | `/v2/pnlExit`                                | GET, POST, DELETE | order_api |
| **Margin calculator**     | `/v2/margincalculator`, `/v2/margincalculator/multi` | POST      | order_api       |
| **Instruments**           | `/v2/instrument/{segment}` (redirect to CSV) | GET       | data_api        |
| **Market feed**           | `/v2/marketfeed/ltp`, `/v2/marketfeed/ohlc`, `/v2/marketfeed/quote` | POST      | data_api / quote_api |
| **Option chain**          | `/v2/optionchain`, `/v2/optionchain/expirylist` | POST      | data_api        |
| **Historical data**       | `/v2/charts/historical`, `/v2/charts/intraday` | POST      | data_api        |
| **Expired options data**  | `/v2/charts/rollingoption`                   | POST      | data_api        |

---

## Auth (outside main client base URL)

| Purpose           | URL / path                     | Method |
|-------------------|--------------------------------|--------|
| Generate token    | `https://auth.dhan.co/app/generateAccessToken` | POST   |
| Renew token       | `https://api.dhan.co/v2/RenewToken`           | POST   |

These are **not** sandbox-aware; they always use the URLs above.

---

## WebSocket endpoints (production only; sandbox not supported)

| Purpose        | URL |
|----------------|-----|
| Order updates  | `wss://api-order-update.dhan.co` |
| Market feed    | `wss://api-feed.dhan.co` |
| Market depth   | `wss://depth-api-feed.dhan.co/twentydepth` |

**Sandbox:** Dhan sandbox does **not** provide WebSocket services. These endpoints are production-only. The gem never switches WS URLs based on `sandbox`; you can still override via `DhanHQ.configuration.ws_order_url`, `ws_market_feed_url`, `ws_market_depth_url`, or env vars `DHAN_WS_ORDER_URL`, `DHAN_WS_MARKET_FEED_URL`, `DHAN_WS_MARKET_DEPTH_URL` if you have a different production URL.

---

## Summary

- **REST:** When `sandbox` is true, all REST calls go to `https://sandbox.dhan.co/v2`. Only `GET /v2/profile` and `GET /v2/fundlimit` are verified working on sandbox; other REST endpoints are not verified — see "Sandbox: verified vs not working / unverified" above.
- **Auth:** Token generation and renewal always use production hosts.
- **WebSockets:** Sandbox does **not** support WebSocket. Order updates, market feed, and market depth always use production URLs; the gem does not publish or use any sandbox WebSocket URLs.

## Call-all-endpoints script

`bin/call_all_endpoints.rb` invokes every REST endpoint exposed by the gem (read-only by default; use `--all` to include write/destructive calls). Useful for connectivity checks or sandbox verification.

```bash
bin/call_all_endpoints.rb              # read-only
bin/call_all_endpoints.rb --list       # print endpoint list
bin/call_all_endpoints.rb --all        # include POST/PUT/DELETE
```

Requires `DHAN_CLIENT_ID` and `DHAN_ACCESS_TOKEN`. Optional: `DHAN_SANDBOX=true`, `DHAN_TEST_SECURITY_ID`, `DHAN_TEST_ORDER_ID`, `DHAN_TEST_ISIN`, `DHAN_TEST_EXPIRY`. When not using `--skip-unavailable`, the script creates a temporary alert for GET/PUT/DELETE alert endpoints and deletes it at exit.
