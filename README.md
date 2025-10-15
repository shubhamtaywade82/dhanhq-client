# DhanHQ — Ruby Client for DhanHQ API (v2)

A clean Ruby client for **Dhan API v2** with ORM-like models (Orders, Positions, Holdings, etc.) **and** a robust **WebSocket market feed** (ticker/quote/full) built on EventMachine + Faye.

* ActiveRecord-style models: `find`, `all`, `where`, `save`, `update`, `cancel`
* Validations & errors exposed via ActiveModel-like interfaces
* REST coverage: Orders, Super Orders, Forever Orders, Trades, Positions, Holdings, Funds/Margin, HistoricalData, OptionChain, MarketFeed
* **WebSocket**: subscribe/unsubscribe dynamically, auto-reconnect with backoff, 429 cool-off, idempotent subs, header+payload binary parsing, normalized ticks

## ⚠️ BREAKING CHANGE NOTICE

**IMPORTANT**: Starting from version 2.1.5, the require statement has changed:

```ruby
# OLD (deprecated)
require 'DhanHQ'

# NEW (current)
require 'dhan_hq'
```

**Migration**: Update all your `require 'DhanHQ'` statements to `require 'dhan_hq'` in your codebase. This change affects:
- All Ruby files that require the gem
- Documentation examples
- Scripts and automation tools
- Rails applications using this gem

The gem name remains `DhanHQ` in your Gemfile, only the require statement changes.

---

## Installation

Add to your Gemfile:

```ruby
gem 'DhanHQ', git: 'https://github.com/shubhamtaywade82/dhanhq-client.git', branch: 'main'
```

Install:

```bash
bundle install
```

Or:

```bash
gem install DhanHQ
```

---

## Configuration

### From ENV / .env

```ruby
require 'dhan_hq'

DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }
```

**Minimum environment variables**

| Variable       | Purpose                                           |
| -------------- | ------------------------------------------------- |
| `CLIENT_ID`    | Trading account client id issued by Dhan.         |
| `ACCESS_TOKEN` | API access token generated from the Dhan console. |

`configure_with_env` raises if either value is missing. Load them via `dotenv`,
Rails credentials, or any other mechanism that populates `ENV` before
initialisation.

**Optional overrides**

Set these variables _before_ calling `configure_with_env` when you need to
override defaults supplied by the gem:

| Variable                                  | When to use                                          |
| ----------------------------------------- | ---------------------------------------------------- |
| `DHAN_LOG_LEVEL`                          | Adjust logger verbosity (`INFO` by default).         |
| `DHAN_BASE_URL`                           | Point REST calls to a different API hostname.        |
| `DHAN_WS_VERSION`                         | Pin to a specific WebSocket API version.             |
| `DHAN_WS_ORDER_URL`                       | Override the order update WebSocket endpoint.        |
| `DHAN_WS_USER_TYPE`                       | Switch between `SELF` and `PARTNER` streaming modes. |
| `DHAN_PARTNER_ID` / `DHAN_PARTNER_SECRET` | Required when `DHAN_WS_USER_TYPE=PARTNER`.           |

### Logging

```ruby
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }
```

---

## Quick Start (REST)

```ruby
# Place an order
order = DhanHQ::Models::Order.new(
  transaction_type: "BUY",
  exchange_segment: "NSE_FNO",
  product_type: "MARGIN",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "43492",
  quantity: 50,
  price: 100.0
)
order.save

# Modify / Cancel
order.modify(price: 101.5)
order.cancel

# Positions / Holdings
positions = DhanHQ::Models::Position.all
holdings  = DhanHQ::Models::Holding.all

# Historical Data (Intraday)
bars = DhanHQ::Models::HistoricalData.intraday(
  security_id: "13",             # NIFTY index value
  exchange_segment: "IDX_I",
  instrument: "INDEX",
  interval: "5",                 # minutes
  from_date: "2025-08-14",
  to_date: "2025-08-18"
)

# Option Chain (example)
oc = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: 1333,        # example underlying ID
  underlying_seg: "NSE_FNO",
  expiry: "2025-08-21"
)
```

### Rails integration

Need a full-stack example inside Rails (REST + WebSockets + automation)? Check
out the [Rails integration guide](docs/rails_integration.md) for
initializers, service objects, workers, and ActionCable wiring tailored for the
`DhanHQ` gem.

---

## WebSocket Market Feed (NEW)

### What you get

* **Modes**

  * `:ticker` → LTP + LTT
  * `:quote`  → OHLCV + totals (recommended default)
  * `:full`   → quote + **OI** + **best-5 depth**
* **Normalized ticks** (Hash):

  ```ruby
  {
    kind: :quote,                 # :ticker | :quote | :full | :oi | :prev_close | :misc
    segment: "NSE_FNO",           # string enum
    security_id: "12345",
    ltp: 101.5,
    ts:  1723791300,              # LTT epoch (sec) if present
    vol: 123456,                  # quote/full
    atp: 100.9,                   # quote/full
    day_open: 100.1, day_high: 102.4, day_low: 99.5, day_close: nil,
    oi: 987654,                   # full or OI packet
    bid: 101.45, ask: 101.55      # from depth (mode :full)
  }
  ```

### Start, subscribe, stop

```ruby
require 'dhan_hq'

DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }

ws = DhanHQ::WS::Client.new(mode: :quote).start

ws.on(:tick) do |t|
  puts "[#{t[:segment]}:#{t[:security_id]}] LTP=#{t[:ltp]} kind=#{t[:kind]}"
end

# Subscribe instruments (≤100 per frame; send multiple frames if needed)
ws.subscribe_one(segment: "IDX_I",   security_id: "13")     # NIFTY index value
ws.subscribe_one(segment: "NSE_FNO", security_id: "12345")  # an option

# Unsubscribe
ws.unsubscribe_one(segment: "NSE_FNO", security_id: "12345")

# Graceful disconnect (sends broker disconnect code 12, no reconnect)
ws.disconnect!

# Or hard stop (no broker message, just closes and halts loop)
ws.stop

# Safety: kill all local sockets (useful in IRB)
DhanHQ::WS.disconnect_all_local!
```

### Under the hood

* **Request codes** (per Dhan docs)

  * Subscribe: **15** (ticker), **17** (quote), **21** (full)
  * Unsubscribe: **16**, **18**, **22**
  * Disconnect: **12**
* **Limits**

  * Up to **100 instruments per SUB/UNSUB** message (client auto-chunks)
  * Up to 5 WS connections per user (per Dhan)
* **Backoff & 429 cool-off**

  * Exponential backoff with jitter
  * Handshake **429** triggers a **60s cool-off** before retry
* **Reconnect & resubscribe**

  * On reconnect the client resends the **current subscription snapshot** (idempotent)
* **Graceful shutdown**

  * `ws.disconnect!` or `ws.stop` prevents reconnects
  * An `at_exit` hook stops all registered WS clients to avoid leaked sockets

---

## Order Update WebSocket (NEW)

Receive live updates whenever your orders transition between states (placed → traded → cancelled, etc.).

### Standalone Ruby script

```ruby
require 'dhan_hq'

DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }

ou = DhanHQ::WS::Orders::Client.new.start

ou.on(:update) do |payload|
  data = payload[:Data] || {}
  puts "ORDER #{data[:OrderNo]} #{data[:Status]} traded=#{data[:TradedQty]} avg=#{data[:AvgTradedPrice]}"
end

# Keep the script alive (CTRL+C to exit)
sleep

# Later, stop the socket
ou.stop
```

Or, if you just need a quick callback:

```ruby
DhanHQ::WS::Orders.connect do |payload|
  # handle :update callbacks only
end
```

### Rails bot integration

Mirror the market-feed supervisor by adding an Order Update hub singleton that hydrates your local DB and hands off to execution services.

1. **Service** – `app/services/live/order_update_hub.rb`

   ```ruby
   Live::OrderUpdateHub.instance.start!
   ```

   The hub wires `DhanHQ::WS::Orders::Client` to:

   * Upsert local `BrokerOrder` rows so UIs always reflect current broker status.
   * Auto-subscribe traded entry legs on your existing `Live::WsHub` (if defined).
   * Refresh `Execution::PositionGuard` (if present) with fill prices/qty for trailing exits.

2. **Initializer** – `config/initializers/order_update_hub.rb`

   ```ruby
   if ENV["ENABLE_WS"] == "true"
     Rails.application.config.to_prepare do
       Live::OrderUpdateHub.instance.start!
     end

     at_exit { Live::OrderUpdateHub.instance.stop! }
   end
   ```

   Flip `ENABLE_WS=true` in your Procfile or `.env` to boot the hub alongside the existing feed supervisor. On shutdown the client is stopped cleanly to avoid leaked sockets.

The hub is resilient to missing dependencies—if you do not have a `BrokerOrder` model, it safely skips persistence while keeping downstream callbacks alive.

---

## Exchange Segment Enums

Use the string enums below in WS `subscribe_*` and REST params:

| Enum           | Exchange | Segment           |
| -------------- | -------- | ----------------- |
| `IDX_I`        | Index    | Index Value       |
| `NSE_EQ`       | NSE      | Equity Cash       |
| `NSE_FNO`      | NSE      | Futures & Options |
| `NSE_CURRENCY` | NSE      | Currency          |
| `BSE_EQ`       | BSE      | Equity Cash       |
| `MCX_COMM`     | MCX      | Commodity         |
| `BSE_CURRENCY` | BSE      | Currency          |
| `BSE_FNO`      | BSE      | Futures & Options |

---

## Accessing ticks elsewhere in your app

### Direct handler

```ruby
ws.on(:tick) { |t| do_something_fast(t) } # avoid heavy work here
```

### Shared TickCache (recommended)

```ruby
# app/services/live/tick_cache.rb
class TickCache
  MAP = Concurrent::Map.new
  def self.put(t)  = MAP["#{t[:segment]}:#{t[:security_id]}"] = t
  def self.get(seg, sid) = MAP["#{seg}:#{sid}"]
  def self.ltp(seg, sid) = get(seg, sid)&.dig(:ltp)
end

ws.on(:tick) { |t| TickCache.put(t) }
ltp = TickCache.ltp("NSE_FNO", "12345")
```

### Filtered callback

```ruby
def on_tick_for(ws, segment:, security_id:, &blk)
  key = "#{segment}:#{security_id}"
  ws.on(:tick){ |t| blk.call(t) if "#{t[:segment]}:#{t[:security_id]}" == key }
end
```

---

## Rails integration (example)

**Goal:** Generate signals from clean **Historical Intraday OHLC** (5-min bars), and use **WebSocket** only for **exits/trailing** on open option legs.

1. **Initializer**
   `config/initializers/dhanhq.rb`

   ```ruby
   DhanHQ.configure_with_env
   DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }
   ```

2. **Start WS supervisor**
   `config/initializers/stream.rb`

   ```ruby
   INDICES = [
     { segment: "IDX_I", security_id: "13" },  # NIFTY index value
     { segment: "IDX_I", security_id: "25" }   # BANKNIFTY index value
   ]

   Rails.application.config.to_prepare do
     $WS = DhanHQ::WS::Client.new(mode: :quote).start
     $WS.on(:tick) do |t|
       TickCache.put(t)
       Execution::PositionGuard.instance.on_tick(t)  # trailing & fast exits
     end
     INDICES.each { |i| $WS.subscribe_one(segment: i[:segment], security_id: i[:security_id]) }
   end
   ```

3. **Bar fetch (every 5 min) via Historical API**

   * Fetch intraday OHLC at 5-minute boundaries.
   * Update your `CandleSeries`; on each closed bar, run strategy to emit signals.
     *(Use your existing `Bars::FetchLoop` + `CandleSeries` code.)*

4. **Routing & orders**

   * On signal: place **Super Order** (SL/TP/TSL) or fallback to Market + local trailing.
   * After a successful place, **register** the leg in `PositionGuard` and **subscribe** its option on WS.

5. **Shutdown**

   ```ruby
   at_exit { DhanHQ::WS.disconnect_all_local! }
   ```

---

## Super Orders

Super orders are built for smart execution. They club the entry, target, and stop-loss legs (with optional trailing jump) into a single request so you can manage risk immediately after entry.

This gem exposes the full REST surface to create, modify, cancel, and list super orders across all supported exchanges and segments.

### Endpoints

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/super/orders` | Create a new super order |
| `PUT` | `/super/orders/{order-id}` | Modify a pending super order |
| `DELETE` | `/super/orders/{order-id}/{order-leg}` | Cancel a pending super order leg |
| `GET` | `/super/orders` | Retrieve the list of all super orders |

### Place Super Order

The place endpoint lets you submit a new super order that can include entry, target, stop-loss, and optional trailing jump definitions. It is available across exchanges and segments, and supports intraday, carry-forward, or MTF orders.

> ℹ️ Static IP whitelisting with Dhan support is required before invoking this API.

```bash
curl --request POST \
  --url https://api.dhan.co/v2/super/orders \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT' \
  --data '{Request JSON}'
```

#### Request body

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

#### Parameters

| Field | Type | Description |
| --- | --- | --- |
| `dhanClientId` | string *(required)* | User specific identification generated by Dhan |
| `correlationId` | string | Caller generated correlation identifier |
| `transactionType` | enum string *(required)* | Trading side. `BUY` or `SELL`. |
| `exchangeSegment` | enum string *(required)* | Exchange segment (see appendix). |
| `productType` | enum string *(required)* | Product type. `CNC`, `INTRADAY`, `MARGIN`, or `MTF`. |
| `orderType` | enum string *(required)* | Order type. `LIMIT` or `MARKET`. |
| `securityId` | string *(required)* | Exchange standard security identifier. |
| `quantity` | integer *(required)* | Number of shares for the order. |
| `price` | float *(required)* | Price at which the entry leg is placed. |
| `targetPrice` | float *(required)* | Target price for the super order. |
| `stopLossPrice` | float *(required)* | Stop-loss price for the super order. |
| `trailingJump` | float *(required)* | Price jump size used to trail the stop-loss. |

#### Response

```json
{
  "orderId": "112111182198",
  "orderStatus": "PENDING"
}
```

| Field | Type | Description |
| --- | --- | --- |
| `orderId` | string | Order identifier generated by Dhan |
| `orderStatus` | enum string | Latest status. `TRANSIT`, `PENDING`, or `REJECTED`. |

### Modify Super Order

Use the modify endpoint to update any leg while the super order remains in `PENDING` or `PART_TRADED` status.

> ℹ️ Static IP whitelisting with Dhan support is required before invoking this API.

```bash
curl --request PUT \
  --url https://api.dhan.co/v2/super/orders/{order-id} \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT' \
  --data '{Request JSON}'
```

#### Request body

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

#### Parameters

| Field | Type | Description |
| --- | --- | --- |
| `dhanClientId` | string *(required)* | User specific identification generated by Dhan. |
| `orderId` | string *(required)* | Super order identifier generated by Dhan. |
| `orderType` | enum string *(conditionally required)* | `LIMIT` or `MARKET`. Required when modifying `ENTRY_LEG`. |
| `legName` | enum string *(required)* | `ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`. Entry leg updates entire order while status is `PENDING` or `PART_TRADED`. |
| `quantity` | integer *(conditionally required)* | Quantity update for `ENTRY_LEG`. |
| `price` | float *(conditionally required)* | Entry price update for `ENTRY_LEG`. |
| `targetPrice` | float *(conditionally required)* | Target price update for `ENTRY_LEG` or `TARGET_LEG`. |
| `stopLossPrice` | float *(conditionally required)* | Stop-loss price update for `ENTRY_LEG` or `STOP_LOSS_LEG`. |
| `trailingJump` | float *(conditionally required)* | Trailing jump update for `ENTRY_LEG` or `STOP_LOSS_LEG`. Omit or set to `0` to cancel trailing. |

> ℹ️ Once the entry leg status becomes `TRADED`, only the `TARGET_LEG` and `STOP_LOSS_LEG` can be modified (price and trailing jump).

#### Response

```json
{
  "orderId": "112111182045",
  "orderStatus": "TRANSIT"
}
```

| Field | Type | Description |
| --- | --- | --- |
| `orderId` | string | Order identifier generated by Dhan |
| `orderStatus` | enum string | Latest status. `TRANSIT`, `PENDING`, `REJECTED`, or `TRADED`. |

### Cancel Super Order

Cancel a pending or active super order leg using the order ID. Cancelling the entry leg removes every leg. Cancelling a specific target or stop-loss leg removes only that leg and it cannot be re-added.

> ℹ️ Static IP whitelisting with Dhan support is required before invoking this API.

```bash
curl --request DELETE \
  --url https://api.dhan.co/v2/super/orders/{order-id}/{order-leg} \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT'
```

#### Path parameters

| Field | Description | Example |
| --- | --- | --- |
| `order-id` | Super order identifier. | `11211182198` |
| `order-leg` | Leg to cancel. `ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`. | `ENTRY_LEG` |

#### Response

```json
{
  "orderId": "112111182045",
  "orderStatus": "CANCELLED"
}
```

| Field | Type | Description |
| --- | --- | --- |
| `orderId` | string | Order identifier generated by Dhan |
| `orderStatus` | enum string | Latest status. `TRANSIT`, `PENDING`, `REJECTED`, or `CANCELLED`. |

### Super Order List

List every super order placed during the trading day. The API nests leg details under the entry leg, and individual legs also appear in the main order book.

```bash
curl --request GET \
  --url https://api.dhan.co/v2/super/orders \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT'
```

#### Response

```json
[
  {
    "dhanClientId": "1100003626",
    "orderId": "5925022734212",
    "correlationId": "string",
    "orderStatus": "PENDING",
    "transactionType": "BUY",
    "exchangeSegment": "NSE_EQ",
    "productType": "CNC",
    "orderType": "LIMIT",
    "validity": "DAY",
    "tradingSymbol": "HDFCBANK",
    "securityId": "1333",
    "quantity": 10,
    "remainingQuantity": 10,
    "ltp": 1660.95,
    "price": 1500,
    "afterMarketOrder": false,
    "legName": "ENTRY_LEG",
    "exchangeOrderId": "11925022734212",
    "createTime": "2025-02-27 19:09:42",
    "updateTime": "2025-02-27 19:09:42",
    "exchangeTime": "2025-02-27 19:09:42",
    "omsErrorDescription": "",
    "averageTradedPrice": 0,
    "filledQty": 0,
    "legDetails": [
      {
        "orderId": "5925022734212",
        "legName": "STOP_LOSS_LEG",
        "transactionType": "SELL",
        "totalQuantity": 0,
        "remainingQuantity": 0,
        "triggeredQuantity": 0,
        "price": 1400,
        "orderStatus": "PENDING",
        "trailingJump": 10
      },
      {
        "orderId": "5925022734212",
        "legName": "TARGET_LEG",
        "transactionType": "SELL",
        "remainingQuantity": 0,
        "triggeredQuantity": 0,
        "price": 1550,
        "orderStatus": "PENDING",
        "trailingJump": 0
      }
    ]
  }
]
```

#### Parameters

| Field | Type | Description |
| --- | --- | --- |
| `dhanClientId` | string | User specific identification generated by Dhan. |
| `orderId` | string | Order identifier generated by Dhan. |
| `correlationId` | string | Correlation identifier supplied by the caller. |
| `orderStatus` | enum string | Latest status. `TRANSIT`, `PENDING`, `CLOSED`, `REJECTED`, `CANCELLED`, `PART_TRADED`, or `TRADED`. |
| `transactionType` | enum string | Trading side. `BUY` or `SELL`. |
| `exchangeSegment` | enum string | Exchange segment. |
| `productType` | enum string | Product type. `CNC`, `INTRADAY`, `MARGIN`, or `MTF`. |
| `orderType` | enum string | Order type. `LIMIT` or `MARKET`. |
| `validity` | enum string | Order validity. `DAY`. |
| `tradingSymbol` | string | Trading symbol reference. |
| `securityId` | string | Exchange security identifier. |
| `quantity` | integer | Ordered quantity. |
| `remainingQuantity` | integer | Quantity pending execution. |
| `ltp` | float | Last traded price. |
| `price` | float | Order price. |
| `afterMarketOrder` | boolean | Indicates if the order was placed after market hours. |
| `legName` | enum string | Leg identifier: `ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`. |
| `trailingJump` | float | Trailing jump for stop-loss. |
| `exchangeOrderId` | string | Exchange-generated order identifier. |
| `createTime` | string | Order creation timestamp. |
| `updateTime` | string | Latest update timestamp. |
| `exchangeTime` | string | Exchange timestamp. |
| `omsErrorDescription` | string | OMS error description when applicable. |
| `averageTradedPrice` | float | Average traded price. |
| `filledQty` | integer | Quantity traded on the exchange. |
| `triggeredQuantity` | integer | Quantity triggered for stop-loss or target legs. |
| `legDetails` | array | Nested leg details for the super order. |

> ✅ `CLOSED` indicates the entry leg plus either target or stop-loss leg completed for the entire quantity. `TRIGGERED` appears on target and stop-loss legs to show which leg fired; inspect `triggeredQuantity` for the executed quantity.

---

## Packet parsing (for reference)

* **Response Header (8 bytes)**:
  `feed_response_code (u8, BE)`, `message_length (u16, BE)`, `exchange_segment (u8, BE)`, `security_id (i32, LE)`
* **Packets supported**:

  * **1** Index (surface as raw/misc unless documented)
  * **2** Ticker: `ltp`, `ltt`
  * **4** Quote: `ltp`, `ltt`, `atp`, `volume`, totals, `day_*`
  * **5** OI: `open_interest`
  * **6** Prev Close: `prev_close`, `oi_prev`
  * **7** Market Status (raw/misc unless documented)
  * **8** Full: quote + `open_interest` + 5× depth (bid/ask)
  * **50** Disconnect: reason code

---

## Best practices

* Keep the `on(:tick)` handler **non-blocking**; push work to a queue/thread.
* Use `mode: :quote` for most strategies; switch to `:full` only if you need depth/OI in real-time.
* Call **`ws.disconnect!`** (or `ws.stop`) when leaving IRB / tests.
  Use **`DhanHQ::WS.disconnect_all_local!`** to be extra safe.
* Don’t exceed **100 instruments per SUB frame** (the client auto-chunks).
* Avoid rapid connect/disconnect loops; the client already **backs off & cools off** when server replies 429.

---

## Troubleshooting

* **429: Unexpected response code**
  You connected too frequently or have too many sockets. The client auto-cools off for **60s** and backs off. Prefer `ws.disconnect!` before reconnecting; and call `DhanHQ::WS.disconnect_all_local!` to kill stragglers.
* **No ticks after reconnect**
  Ensure you re-subscribed after a clean start (the client resends the snapshot automatically on reconnect).
* **Binary parse errors**
  Run with `DHAN_LOG_LEVEL=DEBUG` to inspect; we safely drop malformed frames and keep the loop alive.

---

## Contributing

PRs welcome! Please include tests for new packet decoders and WS behaviors (chunking, reconnect, cool-off).

---

## License

MIT.

## Technical Analysis (Indicators + Multi-Timeframe)

See the guide for computing indicators and aggregating cross-timeframe bias:

- docs/technical_analysis.md
