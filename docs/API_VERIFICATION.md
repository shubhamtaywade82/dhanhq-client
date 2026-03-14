# API Verification (Dhan v2)

Path/behavior alignment with the official Dhan API v2 docs.

**Sources:**

- [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/) – main docs
- [dhanhq.co/docs/v2/edis](https://dhanhq.co/docs/v2/edis/) – EDIS
- [api.dhan.co/v2](https://api.dhan.co/v2/#/) – Developer Kit (when available)

---

## EDIS

**Doc:** [dhanhq.co/docs/v2/edis](https://dhanhq.co/docs/v2/edis/)

| Doc endpoint              | Method | Gem method   | Path / behaviour |
|---------------------------|--------|--------------|-------------------|
| Generate T-PIN            | GET    | `#tpin`      | `/edis/tpin`      |
| Retrieve form & enter T-PIN | POST | `#form(params)` | `/edis/form`; body: `isin`, `qty`, `exchange`, `segment`, `bulk` |
| Bulk form                 | POST   | `#bulk_form(params)` | `/edis/bulkform` (aligned with TODO-1 / legacy) |
| Inquire status            | GET    | `#inquire(isin)` | `/edis/inquire/{isin}` |

**Request (form):** `isin`, `qty`, `exchange` (NSE/BSE), `segment` (EQ), `bulk` (boolean).

---

## Alert Orders

**Doc ref:** [dhanhq.co/docs/v2/conditional-trigger](https://dhanhq.co/docs/v2/conditional-trigger/).

| Doc path                  | Gem resource              | Path used        |
|---------------------------|---------------------------|------------------|
| `/alerts/orders`          | `Resources::AlertOrders`  | `HTTP_PATH = "/v2/alerts/orders"` |
| GET/POST `/alerts/orders` | `#all`, `#create`         | BaseResource     |
| GET/PUT/DELETE `/alerts/orders/{trigger-id}` | `#find`, `#update`, `#delete` | `/{id}` |

Model: `Models::AlertOrder`. Condition must include `exchange_segment`, `exp_date`, `frequency`; `time_frame` required when `comparison_type` starts with `TECHNICAL`. Validated by `AlertOrderContract`.

---

## IP Setup

**Doc ref:** [dhanhq.co/docs/v2/authentication/#setup-static-ip](https://dhanhq.co/docs/v2/authentication/#setup-static-ip).

| Doc path        | Gem method     | Path / body |
|-----------------|----------------|-------------|
| GET /v2/ip/getIP   | `#current`     | `get("/getIP")` (HTTP_PATH = "/v2/ip") |
| POST /v2/ip/setIP  | `#set(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)` | `post("/setIP", params: { ip:, ip_flag:, dhan_client_id: })`; `dhan_client_id` defaults from config |
| PUT /v2/ip/modifyIP| `#update(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)` | `put("/modifyIP", params: { ip:, ip_flag:, dhan_client_id: })` |

---

## Trader Control / Kill Switch

**Doc:** [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/) → Trading APIs → Trader's Control.

- **Kill Switch:** `Resources::KillSwitch`, `Models::KillSwitch` – path `/v2/killswitch`. Manage (activate/deactivate) uses **query parameter**: `POST /v2/killswitch?killSwitchStatus=ACTIVATE` (or `DEACTIVATE`) with no body. `#status` is GET.
- **P&L Exit:** `Models::PnlExit` – path `/v2/pnlExit`. GET status, POST configure, DELETE stop.
- **TraderControl:** `Resources::TraderControl` – path `/trader-control` is **not** in the Dhan v2 API. The class is kept for backward compatibility but raises `DhanHQ::Error` when any method is called; use KillSwitch and PnlExit instead.

---

## Base URL and paths

- Default base URL: `https://api.dhan.co/v2`.
- Resource `HTTP_PATH` values are relative to that base (e.g. `/edis`, `/alerts/orders`, `/ip`).
- Order API resources use `API_TYPE = :order_api`.
