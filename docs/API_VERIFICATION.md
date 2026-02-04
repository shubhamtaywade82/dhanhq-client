# API Verification (Dhan v2)

This document records how the gem’s implementation aligns with the official Dhan API v2 docs.

**Sources:**

- [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/) – main docs
- [dhanhq.co/docs/v2/edis](https://dhanhq.co/docs/v2/edis/) – EDIS
- [api.dhan.co/v2](https://api.dhan.co/v2/#/) – Developer Kit (when available)
- In-repo: `CODE_REVIEW_ISSUES.md` (Alert Orders, IP Setup paths)

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

**Doc ref:** `CODE_REVIEW_ISSUES.md` (§31) – Alert Orders endpoints.

| Doc path                  | Gem resource              | Path used        |
|---------------------------|---------------------------|------------------|
| `/alerts/orders`          | `Resources::AlertOrders`  | `HTTP_PATH = "/alerts/orders"` |
| GET/POST `/alerts/orders` | `#all`, `#create`         | BaseResource     |
| GET/PUT/DELETE `/alerts/orders/{trigger-id}` | `#find`, `#update`, `#delete` | `/{id}` |

Model: `Models::AlertOrder`; ID attribute `alert_id` (response field name may be `alertId` or `triggerId` depending on API; adjust if production returns `triggerId`).

---

## IP Setup

**Doc ref:** `CODE_REVIEW_ISSUES.md` (§32) – IP Setup endpoints.

| Doc path        | Gem method     | Path used     |
|-----------------|----------------|---------------|
| GET /ip/getIP   | `#current`     | `get("/getIP")`   |
| POST /ip/setIP  | `#set(ip:)`    | `post("/setIP", params: { ip: ip })` |
| PUT /ip/modifyIP| `#update(ip:)` | `put("/modifyIP", params: { ip: ip })` |

---

## Trader Control / Kill Switch

- **Existing:** `Resources::KillSwitch`, `Models::KillSwitch` – path `/v2/killswitch`.
- **Added:** `Resources::TraderControl` – path `/trader-control`; `#status`, `#enable`, `#disable`.  
  Not found on the public docs pages checked; kept for compatibility with design that referenced trader-control.

---

## Base URL and paths

- Default base URL: `https://api.dhan.co/v2`.
- Resource `HTTP_PATH` values are relative to that base (e.g. `/edis`, `/alerts/orders`, `/ip`).
- Order API resources use `API_TYPE = :order_api`.
