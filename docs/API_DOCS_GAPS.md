# DhanHQ v2 API docs vs dhanhq-client — gaps and fixes

Reference: [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/)

This document lists mismatches between the official DhanHQ v2 API documentation and the dhanhq-client gem, and suggested fixes.

---

## 1. Kill Switch — request format

**Doc:** [Trader's Control](https://dhanhq.co/docs/v2/traders-control/)

- **Manage Kill Switch:** *"You can pass header parameter as ACTIVATE or DEACTIVATE"* and the curl example uses a **query parameter**:  
  `POST https://api.dhan.co/v2/killswitch?killSwitchStatus=ACTIVATE`  
  **Request structure: No Body**

**Gem:** `Resources::KillSwitch#update(params)` sends a **POST body** with `kill_switch_status: "ACTIVATE"` or `"DEACTIVATE"`.

**Gap:** The API may expect `killSwitchStatus` as a **query parameter** (or header), not in the JSON body. That can explain `DH-905: Missing required fields` when calling activate/deactivate.

**Suggested fix:** In `Resources::KillSwitch#update(status)`, call the API with a query string, e.g. `post("?killSwitchStatus=#{status}")` (or equivalent), and do not send a body. If the live API accepts body and your integration works, this may be a doc inaccuracy; otherwise prefer matching the doc (query param).

**Fixed:** Resource now sends `POST /v2/killswitch?killSwitchStatus=ACTIVATE` (or DEACTIVATE) with no body. Model passes status string to resource.

---

## 2. IP Setup — missing required parameters

**Doc:** [Authentication → Setup Static IP](https://dhanhq.co/docs/v2/authentication/#setup-static-ip)

- **Set IP:** Body must include:
  - `dhanClientId` (required)
  - `ip` (required)
  - `ipFlag` (required): `"PRIMARY"` or `"SECONDARY"`
- **Modify IP:** Same body as Set IP.

**Gem:** `Resources::IPSetup#set(ip:)` and `#update(ip:)` send only `{ ip: ip }`.

**Gap:** `dhanClientId` and `ipFlag` are not sent. Set/Modify IP may fail or behave incorrectly for accounts that require them.

**Suggested fix:** Add `dhan_client_id` and `ip_flag` to the resource (e.g. `set(ip:, ip_flag: "PRIMARY", dhan_client_id: nil)`), defaulting `dhan_client_id` from `DhanHQ.configuration.client_id` when not provided.

**Fixed:** `IPSetup#set` and `#update` now accept `ip:, ip_flag: "PRIMARY"` (or `"SECONDARY"`), and `dhan_client_id:` (defaults from config when nil).

---

## 3. Alert Orders (Conditional Trigger) — condition fields

**Doc:** [Conditional Trigger](https://dhanhq.co/docs/v2/conditional-trigger/)

For **Place** and **Modify**:

- `condition.exchangeSegment` — **required**
- `condition.expDate` — **required** (date, default 1 year)
- `condition.frequency` — **required** (e.g. `"ONCE"`)
- `condition.timeFrame` — required for technical conditions (e.g. `"DAY"`, `"ONE_MIN"`)

**Gem:** `Contracts::AlertOrderContract` and `Models::AlertOrder`:

- Condition has: `security_id`, `comparison_type`, `operator`, and optional `indicator_name`, `time_frame`, `comparing_value`, `comparing_indicator_name`.
- **Missing from contract/model:** `exchange_segment`, `exp_date`, `frequency` in the condition hash.

**Gap:** Creating or modifying alert orders that satisfy the API may require these fields; the gem does not expose or validate them.

**Suggested fix:** Add `exchange_segment`, `exp_date`, and `frequency` to the alert order condition in the contract and model (and ensure they are sent in the API payload in the expected format, e.g. camelCase).

**Fixed:** `AlertOrderContract` condition now requires `exchange_segment`, `exp_date`, `frequency`; rule added so `time_frame` is required when `comparison_type` starts with `TECHNICAL`. Test script and specs updated.

---

## 4. EDIS — doc typo only

**Doc:** [EDIS](https://dhanhq.co/docs/v2/edis/) table lists `POST /edis/from` for the form endpoint.

**Gem:** Uses `POST /edis/form`.

**Conclusion:** The doc table has a typo ("from" vs "form"). The doc’s curl and request structure use `/edis/form`. No change needed in the gem.

---

## 5. Forever Order list — doc inconsistency

**Doc:** [Forever Order](https://dhanhq.co/docs/v2/forever/)

- Table: `GET /forever/orders` — retrieve all forever orders.
- Section "All Forever Order Detail": curl shows `GET /forever/all`.

**Gem:** Uses `GET /forever/orders` (e.g. `ForeverOrders#all` → `get("/orders")` with `HTTP_PATH = "/v2/forever"`).

**Conclusion:** Doc is inconsistent. The gem matches the table. If the API actually uses `/forever/all`, the resource path would need to change; otherwise no change.

---

## 6. P&amp;L Exit — dhanClientId

**Doc:** [Trader's Control → P&amp;L Based Exit](https://dhanhq.co/docs/v2/traders-control/) does not list `dhanClientId` in the request body for Configure.

**Gem:** Was updated to send `dhanClientId` from config when present, to fix `DH-905: dhanClientId is required`.

**Conclusion:** Either the doc omits this field or the API was updated to require it. The gem’s behaviour is aligned with the API response you saw; no further change unless the doc is updated.

---

## Summary table

| Area            | Doc reference        | Gap / note                                                                 | Status   |
|-----------------|----------------------|----------------------------------------------------------------------------|----------|
| Kill Switch     | traders-control      | Manage API expects query param `killSwitchStatus`, not body                | **Fixed** |
| IP Setup        | authentication       | Set/Modify IP required `dhanClientId`, `ipFlag`                            | **Fixed** |
| Alert Orders    | conditional-trigger  | Condition required `exchangeSegment`, `expDate`, `frequency`               | **Fixed** |
| EDIS            | edis                 | Doc typo `/edis/from`; gem correctly uses `/edis/form`                     | None     |
| Forever list    | forever              | Doc inconsistency `/forever/orders` vs `/forever/all`; gem uses `/orders`  | Low      |
| P&amp;L Exit    | traders-control      | Gem sends `dhanClientId`; doc does not mention it                          | None     |

---

## Endpoints covered by the gem (no gaps found)

- **Orders:** Place, modify, cancel, slicing, order book, get by id, get by correlation id — paths and behaviour match the [Orders](https://dhanhq.co/docs/v2/orders/) doc.
- **Trades:** Trade book, trades by order id — match doc.
- **Super Order:** Create, modify, cancel, list — match [Super Order](https://dhanhq.co/docs/v2/super-order/) doc.
- **Forever Order:** Create, modify, cancel, list — paths match [Forever Order](https://dhanhq.co/docs/v2/forever/) table (list path as above).
- **Profile:** GET /v2/profile — match [Authentication → User Profile](https://dhanhq.co/docs/v2/authentication/#user-profile).
- **Trader’s Control:** Kill Switch status (GET), manage via query param (see above). P&amp;L Exit configure/stop/status — match doc.
- **EDIS:** tpin, form, bulkform, inquire — paths and params match [EDIS](https://dhanhq.co/docs/v2/edis/) (form URL as above).
- **Postback:** Incoming webhook payload; gem’s `Postback.parse` is for parsing, not an outgoing API — no endpoint gap.

The Kill Switch query-param change, IP Setup parameter additions, and Alert Order condition fields have been implemented in the gem. See CHANGELOG (Unreleased), GUIDE.md, docs/API_VERIFICATION.md, and docs/TESTING_GUIDE.md for updated documentation.
