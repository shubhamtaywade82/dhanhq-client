# DhanHQ Client API Guide

Use this guide as the companion to the official Dhan API v2 documentation. It maps the public DhanHQ Ruby client classes to the REST and WebSocket endpoints, highlights the validations enforced by the gem, and shows how to compose end-to-end flows without tripping over common pitfalls.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Working With Models](#working-with-models)
3. [Orders](#orders)
4. [Super & Forever Orders](#super--forever-orders)
5. [Portfolio & Funds](#portfolio--funds)
6. [Trade & Ledger Data](#trade--ledger-data)
7. [Data & Market Services](#data--market-services)
8. [Account Utilities](#account-utilities)
9. [Constants & Enums](#constants--enums)
10. [Error Handling](#error-handling)
11. [Best Practices](#best-practices)

---

## Getting Started

```ruby
# Gemfile
gem 'DhanHQ', git: 'https://github.com/shubhamtaywade82/dhanhq-client.git', branch: 'main'
```

```bash
bundle install
```

Bootstrap from environment variables:

```ruby
require 'dhan_hq'

DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }
```

**Minimum requirements**

`configure_with_env` reads from `ENV` and raises unless both variables are set:

| Variable | Description |
| --- | --- |
| `CLIENT_ID` | Your Dhan trading client id. |
| `ACCESS_TOKEN` | REST/WebSocket access token generated via Dhan APIs. |

Provide them via `.env`, Rails credentials, or your secret manager of choice
before the initializer runs.

**Optional overrides**

Set any of the following environment variables _before_ calling
`configure_with_env` to customise runtime behaviour:

| Variable | Purpose |
| --- | --- |
| `DHAN_LOG_LEVEL` | Change logger verbosity (`INFO` default). |
| `DHAN_BASE_URL` | Override the REST API host. |
| `DHAN_WS_VERSION` | Target a specific WebSocket API version. |
| `DHAN_WS_ORDER_URL` | Customise the order update WebSocket endpoint. |
| `DHAN_WS_USER_TYPE` | Toggle between `SELF` and `PARTNER` streaming modes. |
| `DHAN_PARTNER_ID` / `DHAN_PARTNER_SECRET` | Required when streaming as a partner. |

---

## Working With Models

All models inherit from `DhanHQ::BaseModel` and expose a consistent API:

- **Class helpers**: `.all`, `.find`, `.create`, and, where available, `.where`, `.history`, `.today`
- **Instance helpers**: `#save`, `#modify`, `#cancel`, `#refresh`, `#destroy`
- **Validation**: the gem wraps Dry::Validation contracts. Validation errors raise `DhanHQ::Error`.
- **Parameter naming**:
  - Ruby-facing APIs (e.g. `Order.place`, `Order#slice_order`, `Margin.calculate`, `Position.convert`) accept snake_case keys and symbols. The client handles camelCase conversion before hitting the REST API.
  - When you work with the raw `DhanHQ::Resources::*` classes directly, supply the fields exactly as documented by the REST API.
- **Responses**: model constructors normalise keys to snake_case and expose attribute reader methods. Raw API hashes are wrapped in `HashWithIndifferentAccess` for easy lookup.

---

## Orders

### Available Methods

```ruby
order = DhanHQ::Models::Order.place(payload)    # validate + POST + fetch order details
order = DhanHQ::Models::Order.create(payload)   # build + #save (AR-style)
orders = DhanHQ::Models::Order.all              # current-day order book
order  = DhanHQ::Models::Order.find(order_id)
order  = DhanHQ::Models::Order.find_by_correlation(correlation_id)
```

Instance workflow:

```ruby
order = DhanHQ::Models::Order.new(params)
order.save              # place or modify depending on presence of order_id
order.modify(price: 101.5)
order.cancel
order.refresh
```

### Placement Payload (Order.place / Order#create / Order#save)

Required fields validated by `DhanHQ::Contracts::PlaceOrderContract`:

| Key               | Type    | Allowed Values / Notes |
| ----------------- | ------- | ---------------------- |
| `transaction_type`| String  | `BUY`, `SELL` |
| `exchange_segment`| String  | Use `DhanHQ::Constants::EXCHANGE_SEGMENTS` |
| `product_type`    | String  | `CNC`, `INTRADAY`, `MARGIN`, `MTF`, `CO`, `BO` |
| `order_type`      | String  | `LIMIT`, `MARKET`, `STOP_LOSS`, `STOP_LOSS_MARKET` |
| `validity`        | String  | `DAY`, `IOC` |
| `security_id`     | String  | Security identifier from the scrip master |
| `quantity`        | Integer | Must be > 0 |

Optional fields and special rules:

| Key                   | Type    | Notes |
| --------------------- | ------- | ----- |
| `correlation_id`      | String  | ≤ 25 chars; useful for idempotency |
| `disclosed_quantity`  | Integer | ≥ 0 and ≤ 30% of `quantity` |
| `trading_symbol`      | String  | Optional label |
| `price`               | Float   | Mandatory for `LIMIT` |
| `trigger_price`       | Float   | Mandatory for SL / SLM |
| `after_market_order`  | Boolean | Require `amo_time` when true |
| `amo_time`            | String  | `OPEN`, `OPEN_30`, `OPEN_60` (check `DhanHQ::Constants::AMO_TIMINGS` for updates) |
| `bo_profit_value`     | Float   | Required with `product_type: "BO"` |
| `bo_stop_loss_value`  | Float   | Required with `product_type: "BO"` |
| `drv_expiry_date`     | String  | Pass ISO `YYYY-MM-DD` for derivatives |
| `drv_option_type`     | String  | `CALL`, `PUT`, `NA` |
| `drv_strike_price`    | Float   | > 0 |

Example:

```ruby
payload = {
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "CNC",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "1333",
  quantity: 10,
  price: 150.0,
  correlation_id: "hs20240910-01"
}

order = DhanHQ::Models::Order.place(payload)
puts order.order_status  # => "TRADED" / "PENDING" / ...
```

### Modification & Cancellation

`Order#modify` merges the existing attributes with the supplied overrides and validates against `ModifyOrderContract`.

- Required: the instance must have an `order_id` and `dhan_client_id`.
- At least one of `order_type`, `quantity`, `price`, `trigger_price`, `disclosed_quantity`, `validity` must change.
- Payload is camelised automatically before hitting `/v2/orders/{orderId}`.

```ruby
order.modify(price: 154.2, trigger_price: 149.5)
order.cancel
```

For raw updates (e.g. background jobs) you can call the resource directly:

```ruby
params = DhanHQ::Models::Order.camelize_keys(order_id: "123", price: 100.0)
DhanHQ::Contracts::ModifyOrderContract.new.call(params).success?
DhanHQ::Models::Order.resource.update("123", params)
```

### Slicing Orders

Use the same fields as placement, but the contract allows additional validity options (`GTC`, `GTD`). The model helper accepts snake_case parameters and handles camelCase conversion as part of validation:

```ruby
slice_payload = {
  order_id: order.order_id,
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "STOP_LOSS",
  order_type: "STOP_LOSS",
  validity: "GTC",
  security_id: "1333",
  quantity: 100,
  trigger_price: 148.5,
  price: 150.0
}

order.slice_order(slice_payload)
```

When you call the resource layer directly, camelCase the keys first so they match the REST contract:

```ruby
payload = DhanHQ::Models::Order.camelize_keys(slice_payload)
DhanHQ::Contracts::SliceOrderContract.new.call(payload).success?
DhanHQ::Models::Order.resource.slicing(payload)
```

---

## Super & Forever Orders

### Super Orders

`DhanHQ::Models::SuperOrder` wraps the `/v2/super/orders` family. A super order combines entry, target, and stop-loss legs into one atomic instruction and supports an optional trailing jump so risk is managed server-side immediately after entry.

#### Endpoints

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/super/orders` | Create a new super order |
| `PUT` | `/super/orders/{order-id}` | Modify a pending super order |
| `DELETE` | `/super/orders/{order-id}/{order-leg}` | Cancel a pending super order leg |
| `GET` | `/super/orders` | Retrieve the list of all super orders |

#### Place Super Order

> ℹ️ Static IP whitelisting with Dhan support is required before invoking these APIs.

```bash
curl --request POST \
  --url https://api.dhan.co/v2/super/orders \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT' \
  --data '{Request JSON}'
```

Request body:

```json
{
  "dhanClientId": "1000000003",
  "correlationId": "123abc678",
  "transactionType": "BUY",
  "exchangeSegment": "NSE_EQ",
  "productType": "CNC",
  "orderType": "LIMIT",
  "securityId": "11536",
  "quantity": 5,
  "price": 1500,
  "targetPrice": 1600,
  "stopLossPrice": 1400,
  "trailingJump": 10
}
```

Key parameters:

| Field | Type | Notes |
| --- | --- | --- |
| `dhanClientId` | string *(required)* | User specific identifier generated by Dhan. |
| `correlationId` | string | Optional caller supplied correlation id. |
| `transactionType` | enum string *(required)* | `BUY` or `SELL`. |
| `exchangeSegment` | enum string *(required)* | Exchange segment. |
| `productType` | enum string *(required)* | `CNC`, `INTRADAY`, `MARGIN`, or `MTF`. |
| `orderType` | enum string *(required)* | `LIMIT` or `MARKET`. |
| `securityId` | string *(required)* | Exchange security identifier. |
| `quantity` | integer *(required)* | Entry quantity. |
| `price` | float *(required)* | Entry price. |
| `targetPrice` | float *(required)* | Target price for the super order. |
| `stopLossPrice` | float *(required)* | Stop-loss price for the super order. |
| `trailingJump` | float *(required)* | Trailing jump size. |

Response:

```json
{
  "orderId": "112111182198",
  "orderStatus": "PENDING"
}
```

#### Modify Super Order

Modify while the order is `PENDING` or `PART_TRADED`. Entry leg updates adjust the entire super order until the entry trades; afterwards only target and stop-loss legs (price, trailing) remain editable.

```bash
curl --request PUT \
  --url https://api.dhan.co/v2/super/orders/{order-id} \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT' \
  --data '{Request JSON}'
```

Example payload:

```json
{
  "dhanClientId": "1000000009",
  "orderId": "112111182045",
  "orderType": "LIMIT",
  "legName": "ENTRY_LEG",
  "quantity": 40,
  "price": 1300,
  "targetPrice": 1450,
  "stopLossPrice": 1350,
  "trailingJump": 20
}
```

Conditional fields:

| Field | Required when | Notes |
| --- | --- | --- |
| `orderType` | Updating `ENTRY_LEG` | `LIMIT` or `MARKET`. |
| `quantity` | Updating `ENTRY_LEG` | Adjusts entry quantity. |
| `price` | Updating `ENTRY_LEG` | Adjusts entry price. |
| `targetPrice` | Updating `ENTRY_LEG` or `TARGET_LEG` | Adjusts target price. |
| `stopLossPrice` | Updating `ENTRY_LEG` or `STOP_LOSS_LEG` | Adjusts stop-loss price. |
| `trailingJump` | Updating `ENTRY_LEG` or `STOP_LOSS_LEG` | Pass `0` or omit to cancel trailing. |

Response:

```json
{
  "orderId": "112111182045",
  "orderStatus": "TRANSIT"
}
```

#### Cancel Super Order

```bash
curl --request DELETE \
  --url https://api.dhan.co/v2/super/orders/{order-id}/{order-leg} \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT'
```

Path parameters:

| Field | Description | Example |
| --- | --- | --- |
| `order-id` | Super order identifier. | `11211182198` |
| `order-leg` | Leg to cancel (`ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`). | `ENTRY_LEG` |

Response:

```json
{
  "orderId": "112111182045",
  "orderStatus": "CANCELLED"
}
```

#### Super Order List

```bash
curl --request GET \
  --url https://api.dhan.co/v2/super/orders \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT'
```

The response returns one object per super order with nested `legDetails`. Key attributes include `orderStatus`, `filledQty`, `remainingQuantity`, `averageTradedPrice`, and leg-level trailing configuration. `CLOSED` indicates the entry plus either target or stop-loss filled the entire quantity; `TRIGGERED` surfaces on the target or stop-loss leg that fired.

### Forever Orders (GTT)

`DhanHQ::Models::ForeverOrder` maps to `/v2/forever/orders`.

```ruby
params = {
  dhanClientId: "123456",
  transactionType: "SELL",
  exchangeSegment: "NSE_EQ",
  productType: "CNC",
  orderType: "LIMIT",
  validity: "DAY",
  securityId: "1333",
  price: 200.0,
  triggerPrice: 198.0
}

forever_order = DhanHQ::Models::ForeverOrder.create(params)
forever_order.modify(price: 205.0)
forever_order.cancel
```

The forever order helpers accept snake_case parameters and camelize them internally; only the low-level resource requires raw API casing.

---

## Portfolio & Funds

### Positions

```ruby
positions = DhanHQ::Models::Position.all     # includes closed legs
open_positions = DhanHQ::Models::Position.active
```

Convert an intraday position to delivery (or vice versa):

```ruby
convert_payload = {
  dhan_client_id: "123456",
  security_id: "1333",
  from_product_type: "INTRADAY",
  to_product_type: "CNC",
  convert_qty: 10,
  exchange_segment: "NSE_EQ",
  position_type: "LONG"
}

response = DhanHQ::Models::Position.convert(convert_payload)
raise response.errors.to_s if response.is_a?(DhanHQ::ErrorObject)
```

The conversion helper validates the payload with `PositionConversionContract`; missing or invalid fields raise `DhanHQ::Error` before the request is sent.

### Holdings

```ruby
holdings = DhanHQ::Models::Holding.all
holdings.first.avg_cost_price
```

### Funds

```ruby
funds = DhanHQ::Models::Funds.fetch
puts funds.available_balance

balance = DhanHQ::Models::Funds.balance
```

API quirk: the REST response currently returns `availabelBalance`. The model maps it automatically to `available_balance`.

---

## Trade & Ledger Data

### Trades

```ruby
# Historical trades
history = DhanHQ::Models::Trade.history(from_date: "2024-01-01", to_date: "2024-01-31", page: 0)

# Current day trade book
trade_book = DhanHQ::Models::Trade.today

# Trade details for a specific order (today)
trade = DhanHQ::Models::Trade.find_by_order_id("ORDER123")
```

### Ledger Entries

```ruby
ledger = DhanHQ::Models::LedgerEntry.all(from_date: "2024-04-01", to_date: "2024-04-30")
ledger.each { |entry| puts "#{entry.voucherdate} #{entry.narration} #{entry.runbal}" }
```

Both endpoints return arrays and skip validation because they represent historical data dumps.

---

## Data & Market Services

### Historical Data

`DhanHQ::Models::HistoricalData` enforces `HistoricalDataContract` before delegating to `/v2/charts`.

| Key                | Type   | Notes |
| ------------------ | ------ | ----- |
| `security_id`      | String | Required |
| `exchange_segment` | String | See `EXCHANGE_SEGMENTS` |
| `instrument`       | String | Use `DhanHQ::Constants::INSTRUMENTS` |
| `from_date`        | String | `YYYY-MM-DD` |
| `to_date`          | String | `YYYY-MM-DD` |
| `expiry_code`      | Integer| Optional (`0`, `1`, `2`) |
| `interval`         | String | Optional (`1`, `5`, `15`, `25`, `60`) for intraday |

```ruby
bars = DhanHQ::Models::HistoricalData.intraday(
  security_id: "13",
  exchange_segment: "IDX_I",
  instrument: "INDEX",
  interval: "5",
  from_date: "2024-08-14",
  to_date: "2024-08-14"
)
```

### Option Chain

```ruby
chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: 1333,
  underlying_seg: "NSE_FNO",
  expiry: "2024-12-26"
)

expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
  underlying_scrip: 1333,
  underlying_seg: "NSE_FNO"
)
```

The model filters strikes where both CE and PE have zero `last_price`, keeping the payload compact.

### Margin Calculator

`DhanHQ::Models::Margin.calculate` camelizes your snake_case keys and validates with `MarginCalculatorContract` before posting to `/v2/margincalculator`:

```ruby
params = {
  dhan_client_id: "123456",
  exchange_segment: "NSE_EQ",
  transaction_type: "BUY",
  quantity: 10,
  product_type: "INTRADAY",
  security_id: "1333",
  price: 150.0
}

margin = DhanHQ::Models::Margin.calculate(params)
puts margin.total_margin
```

If a required field is missing (for example `transaction_type`), the contract raises `DhanHQ::Error` before any API call is issued.

### REST Market Feed (Batch LTP/OHLC/Quote)

```ruby
payload = {
  "NSE_EQ" => [11536, 3456],
  "NSE_FNO" => [49081, 49082]
}

ltp   = DhanHQ::Models::MarketFeed.ltp(payload)
ohlc  = DhanHQ::Models::MarketFeed.ohlc(payload)
quote = DhanHQ::Models::MarketFeed.quote(payload)
```

These endpoints are rate-limited by Dhan. The client’s internal `RateLimiter` throttles calls—consider batching symbols sensibly.

### WebSocket Market Feed

The gem provides a resilient EventMachine + Faye wrapper. Minimal setup:

```ruby
DhanHQ.configure_with_env
ws = DhanHQ::WS::Client.new(mode: :quote).start

ws.on(:tick) do |tick|
  puts "[#{tick[:segment]} #{tick[:security_id]}] LTP=#{tick[:ltp]} kind=#{tick[:kind]}"
end

ws.subscribe_one(segment: "IDX_I", security_id: "13")
ws.unsubscribe_one(segment: "IDX_I", security_id: "13")

ws.disconnect!
```

Modes: `:ticker`, `:quote`, `:full`. The client handles reconnects, 429 cool-offs, and idempotent subscriptions.

---

## Account Utilities

### Profile

```ruby
profile = DhanHQ::Models::Profile.fetch
profile.dhan_client_id   # => "1100003626"
profile.token_validity   # => "30/03/2025 15:37"
profile.active_segment   # => "Equity, Derivative, Currency, Commodity"
```

If the credentials are invalid the helper raises `DhanHQ::InvalidAuthenticationError`.

### EDIS (Electronic Delivery Instruction Slip)

```ruby
# Generate a CDSL form for a single ISIN
form = DhanHQ::Models::Edis.form(
  isin: "INE0ABCDE123",
  qty: 1,
  exchange: "NSE",
  segment: "EQ",
  bulk: false
)

# Prepare a bulk file
bulk_form = DhanHQ::Models::Edis.bulk_form(
  isin: %w[INE0ABCDE123 INE0XYZ89012],
  exchange: "NSE",
  segment: "EQ"
)

# Manage T-PIN and status inquiries
DhanHQ::Models::Edis.tpin                    # => {"status"=>"TPIN sent"}
authorisations = DhanHQ::Models::Edis.inquire("ALL")
```

All helpers accept snake_case keys; the client camelizes them before calling `/v2/edis/...`.

### Kill Switch

```ruby
DhanHQ::Models::KillSwitch.activate    # => {"killSwitchStatus"=>"ACTIVATE"}
DhanHQ::Models::KillSwitch.deactivate  # => {"killSwitchStatus"=>"DEACTIVATE"}

# Explicit status update
DhanHQ::Models::KillSwitch.update("ACTIVATE")
```

Only `"ACTIVATE"` and `"DEACTIVATE"` are accepted—any other value raises `DhanHQ::Error`.

---

## Constants & Enums

Use `DhanHQ::Constants` for canonical values:

- `TRANSACTION_TYPES`
- `EXCHANGE_SEGMENTS`
- `PRODUCT_TYPES`
- `ORDER_TYPES`
- `VALIDITY_TYPES`
- `AMO_TIMINGS`
- `INSTRUMENTS`
- `ORDER_STATUSES`
- CSV URLs: `COMPACT_CSV_URL`, `DETAILED_CSV_URL`
- `DHAN_ERROR_MAPPING` for mapping broker error codes to Ruby exceptions

Example:

```ruby
validity = DhanHQ::Constants::VALIDITY_TYPES # => ["DAY", "IOC"]
```

---

## Error Handling

The client normalises broker error payloads and raises specific subclasses of `DhanHQ::Error` (see `lib/DhanHQ/errors.rb`). Key mappings:

- `InvalidAuthenticationError` → `DH-901`
- `InvalidAccessError` → `DH-902`
- `UserAccountError` → `DH-903`
- `RateLimitError` → `DH-904`, HTTP 429/805
- `InputExceptionError` → `DH-905`
- `OrderError` → `DH-906`
- `DataError` → `DH-907`
- `InternalServerError` → `DH-908`, `800`
- `NetworkError` → `DH-909`
- `OtherError` → `DH-910`
- `InvalidTokenError`, `InvalidClientIDError`, `InvalidRequestError` for the remaining broker error codes (`807`–`814`)

Handle errors explicitly while placing orders:

```ruby
begin
  order = DhanHQ::Models::Order.place(payload)
  puts "Order status: #{order.order_status}"
rescue DhanHQ::InvalidAuthenticationError => e
  warn "Auth failed: #{e.message}"
rescue DhanHQ::OrderError => e
  warn "Order rejected: #{e.message}"
rescue DhanHQ::RateLimitError => e
  warn "Slow down: #{e.message}"
end
```

---

## Best Practices

1. Validate payloads locally (`DhanHQ::Contracts::*`) before hitting the API in batch scripts.
2. Use `correlation_id` to make order placement idempotent across retries.
3. Call `Order#refresh` or `Order.find` after placement when you depend on derived fields like `average_traded_price` or `filled_qty`.
4. Respect the built-in rate limiter; space out historical data and market feed calls to avoid `DH-904`/805 errors.
5. Keep enum values in sync by referencing `DhanHQ::Constants`; avoid hardcoding strings in application code.
6. Capture and persist broker error codes—they are mapped to Ruby error classes but still valuable for support tickets.
7. For WebSocket feeds, subscribe in frames ≤ 100 instruments and handle reconnect callbacks to resubscribe cleanly.

---

Always cross-check with https://dhanhq.co/docs/v2/ for endpoint-specific nuances. The Ruby client aims to mirror those contracts while adding guard rails and idiomatic ergonomics.
