# DhanHQ — Ruby Client for DhanHQ API (v2)

A clean Ruby client for **Dhan API v2** with ORM-like models (Orders, Positions, Holdings, etc.) **and** a robust **WebSocket market feed** (ticker/quote/full) built on EventMachine + Faye.

* ActiveRecord-style models: `find`, `all`, `where`, `save`, `update`, `cancel`
* Validations & errors exposed via ActiveModel-like interfaces
* REST coverage: Orders, Super Orders, Forever Orders, Trades, Positions, Holdings, Funds/Margin, HistoricalData, OptionChain, MarketFeed, ExpiredOptionsData
* **WebSocket**: Orders, Market Feed, Market Depth - subscribe/unsubscribe dynamically, auto-reconnect with backoff, 429 cool-off, idempotent subs, header+payload binary parsing, normalized ticks

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

### Testing & Development

For comprehensive testing examples and interactive console helpers, see the [Testing Guide](docs/TESTING_GUIDE.md). The guide includes:

- **WebSocket Testing**: Market feed, order updates, and market depth examples
- **Model Testing**: Complete examples for all models (Orders, Positions, Holdings, etc.)
- **Validation Contracts**: Testing all validation contracts
- **Error Handling**: Testing error scenarios and recovery
- **Quick Helpers**: Load `bin/test_helpers.rb` in console for quick test functions

**Quick start in console:**
```ruby
# Start console
bin/console

# Load test helpers
load 'bin/test_helpers.rb'

# Run quick tests
run_all_tests

# Or test individual features
test_funds
test_market_feed
test_orders
```

---

## WebSocket Integration (Orders, Market Feed, Market Depth)

The DhanHQ gem provides comprehensive WebSocket integration with three distinct WebSocket types, featuring improved architecture, security, and reliability:

### Key Features

- **🔒 Secure Logging** - Sensitive information (access tokens) are automatically sanitized from logs
- **⚡ Rate Limit Protection** - Built-in protection against 429 errors with proper connection management
- **🔄 Automatic Reconnection** - Exponential backoff with 60-second cool-off periods
- **🧵 Thread-Safe Operation** - Safe for Rails applications and multi-threaded environments
- **📊 Comprehensive Examples** - Ready-to-use examples for all WebSocket types
- **🛡️ Error Handling** - Robust error handling and connection management
- **🔍 Dynamic Symbol Resolution** - Easy instrument lookup using `.find()` method

### 1. Orders WebSocket - Real-time Order Updates

Receive live updates whenever your orders transition between states (placed → traded → cancelled, etc.).

```ruby
# Simple connection
DhanHQ::WS::Orders.connect do |order_update|
  puts "Order Update: #{order_update.order_no} - #{order_update.status}"
  puts "  Symbol: #{order_update.symbol}"
  puts "  Quantity: #{order_update.quantity}"
  puts "  Traded Qty: #{order_update.traded_qty}"
  puts "  Price: #{order_update.price}"
  puts "  Execution: #{order_update.execution_percentage}%"
end

# Advanced usage with multiple event handlers
client = DhanHQ::WS::Orders.client
client.on(:update) { |order| puts "📝 Order updated: #{order.order_no}" }
client.on(:status_change) { |change| puts "🔄 Status: #{change[:previous_status]} -> #{change[:new_status]}" }
client.on(:execution) { |exec| puts "✅ Executed: #{exec[:new_traded_qty]} shares" }
client.on(:order_rejected) { |order| puts "❌ Rejected: #{order.order_no}" }
client.start
```

### 2. Market Feed WebSocket - Live Market Data

Subscribe to real-time market data for indices and stocks.

```ruby
# Ticker data (LTP updates) - Recommended for most use cases
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
end

# Subscribe to major Indian indices
market_client.subscribe_one(segment: "IDX_I", security_id: "13")  # NIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "25")  # BANKNIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "29")  # NIFTYIT
market_client.subscribe_one(segment: "IDX_I", security_id: "51")  # SENSEX

# Quote data (LTP + volume + OHLC)
DhanHQ::WS.connect(mode: :quote) do |quote|
  puts "#{quote[:symbol]}: LTP=#{quote[:ltp]}, Volume=#{quote[:vol]}"
end

# Full market data
DhanHQ::WS.connect(mode: :full) do |full|
  puts "#{full[:symbol]}: #{full.inspect}"
end
```

### 3. Market Depth WebSocket - Real-time Market Depth

Get real-time market depth data including bid/ask levels and order book information.

```ruby
# Real-time market depth for stocks (using dynamic symbol resolution with underlying_symbol)
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

symbols = []
if reliance
  symbols << { symbol: "RELIANCE", exchange_segment: reliance.exchange_segment, security_id: reliance.security_id }
end
if tcs
  symbols << { symbol: "TCS", exchange_segment: tcs.exchange_segment, security_id: tcs.security_id }
end

DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
  puts "Market Depth: #{depth_data[:symbol]}"
  puts "  Best Bid: #{depth_data[:best_bid]}"
  puts "  Best Ask: #{depth_data[:best_ask]}"
  puts "  Spread: #{depth_data[:spread]}"
  puts "  Bid Levels: #{depth_data[:bids].size}"
  puts "  Ask Levels: #{depth_data[:asks].size}"
end
```

### Unified WebSocket Architecture

All WebSocket connections provide:
- **Automatic reconnection** with exponential backoff
- **Thread-safe operation** for Rails applications
- **Consistent event handling** patterns
- **Built-in error handling** and logging
- **429 rate limiting** protection with cool-off periods
- **Secure logging** with automatic credential sanitization

### Connection Management

```ruby
# Sequential connections to avoid rate limiting (recommended)
orders_client = DhanHQ::WS::Orders.connect { |order| puts "Order: #{order.order_no}" }
orders_client.stop
sleep(2)  # Wait between connections

market_client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts "Market: #{tick[:symbol]}" }
market_client.stop
sleep(2)

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) { |depth| puts "Depth: #{depth[:symbol]}" }
depth_client.stop

# Check connection status
puts "Orders connected: #{orders_client.connected?}"
puts "Market connected: #{market_client.connected?}"
puts "Depth connected: #{depth_client.connected?}"

# Graceful shutdown
DhanHQ::WS.disconnect_all_local!
```

### Examples

The gem includes comprehensive examples in the `examples/` directory:

- `market_feed_example.rb` - Market Feed WebSocket with major indices
- `order_update_example.rb` - Order Update WebSocket with event handling
- `market_depth_example.rb` - Market Depth WebSocket with RELIANCE and TCS
- `comprehensive_websocket_examples.rb` - All three WebSocket types

Run examples:

```bash
# Individual examples
bundle exec ruby examples/market_feed_example.rb
bundle exec ruby examples/order_update_example.rb
bundle exec ruby examples/market_depth_example.rb

# Comprehensive example
bundle exec ruby examples/comprehensive_websocket_examples.rb
```

### Instrument Model with Trading Fields

The Instrument model now includes comprehensive trading fields for order validation, risk management, and compliance:

```ruby
# Find instrument with trading fields
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")

# Trading permissions and restrictions
puts "Trading Allowed: #{reliance.buy_sell_indicator == 'A'}"
puts "Bracket Orders: #{reliance.bracket_flag == 'Y' ? 'Supported' : 'Not Supported'}"
puts "Cover Orders: #{reliance.cover_flag == 'Y' ? 'Supported' : 'Not Supported'}"
puts "ASM/GSM Status: #{reliance.asm_gsm_flag == 'Y' ? reliance.asm_gsm_category : 'No Restrictions'}"

# Margin and leverage information
puts "ISIN: #{reliance.isin}"
puts "MTF Leverage: #{reliance.mtf_leverage}x"
puts "Buy Margin %: #{reliance.buy_co_min_margin_per}%"
puts "Sell Margin %: #{reliance.sell_co_min_margin_per}%"
```

**Available Trading Fields:**
- `isin` - International Securities Identification Number
- `instrument_type` - Classification (ES, INDEX, FUT, OPT)
- `expiry_flag` - Whether instrument has expiry
- `bracket_flag` - Bracket order support
- `cover_flag` - Cover order support
- `asm_gsm_flag` - Additional Surveillance Measure status
- `buy_sell_indicator` - Trading permission
- `buy_co_min_margin_per` - Buy CO minimum margin percentage
- `sell_co_min_margin_per` - Sell CO minimum margin percentage
- `mtf_leverage` - Margin Trading Facility leverage

### Instrument Convenience Methods

The Instrument model provides convenient instance methods that automatically use the instrument's attributes (`security_id`, `exchange_segment`, `instrument`) to fetch market data:

```ruby
# Find an instrument
instrument = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")

# Market Feed Methods - automatically uses instrument's attributes
ltp_data = instrument.ltp        # Last traded price
ohlc_data = instrument.ohlc     # OHLC data
quote_data = instrument.quote   # Full quote depth

# Historical Data Methods
daily_data = instrument.daily(
  from_date: "2024-01-01",
  to_date: "2024-01-31",
  expiry_code: 0  # Optional
)

intraday_data = instrument.intraday(
  from_date: "2024-09-11",
  to_date: "2024-09-15",
  interval: "15"  # 1, 5, 15, 25, or 60 minutes
)

# Option Chain Methods
expiries = instrument.expiry_list  # Get all available expiries

chain = instrument.option_chain(expiry: "2024-02-29")  # Get option chain for specific expiry
```

**Available Instance Methods:**
- `instrument.ltp` - Fetches last traded price using `DhanHQ::Models::MarketFeed.ltp`
- `instrument.ohlc` - Fetches OHLC data using `DhanHQ::Models::MarketFeed.ohlc`
- `instrument.quote` - Fetches full quote depth using `DhanHQ::Models::MarketFeed.quote`
- `instrument.daily(from_date:, to_date:, **options)` - Fetches daily historical data using `DhanHQ::Models::HistoricalData.daily`
- `instrument.intraday(from_date:, to_date:, interval:, **options)` - Fetches intraday historical data using `DhanHQ::Models::HistoricalData.intraday`
- `instrument.expiry_list` - Fetches expiry list using `DhanHQ::Models::OptionChain.fetch_expiry_list`
- `instrument.option_chain(expiry:)` - Fetches option chain using `DhanHQ::Models::OptionChain.fetch`

All methods automatically use the instrument's `security_id`, `exchange_segment`, and `instrument` attributes, eliminating the need to manually pass these parameters.

### Comprehensive Documentation

The gem includes detailed documentation for different integration scenarios:

- **[WebSocket Integration Guide](docs/websocket_integration.md)** - Complete guide covering all WebSocket types and trading fields
- **[Rails Integration Guide](docs/rails_websocket_integration.md)** - Rails-specific patterns and best practices
- **[Standalone Ruby Guide](docs/standalone_ruby_websocket_integration.md)** - Scripts, daemons, and CLI tools

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

| Method   | Path                                   | Description                           |
| -------- | -------------------------------------- | ------------------------------------- |
| `POST`   | `/super/orders`                        | Create a new super order              |
| `PUT`    | `/super/orders/{order_id}`             | Modify a pending super order          |
| `DELETE` | `/super/orders/{order_id}/{order_leg}` | Cancel a pending super order leg      |
| `GET`    | `/super/orders`                        | Retrieve the list of all super orders |

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
  "dhan_client_id": "1000000003",
  "correlation_id": "123abc678",
  "transaction_type": "BUY",
  "exchange_segment": "NSE_EQ",
  "product_type": "CNC",
  "order_type": "LIMIT",
  "security_id": "11536",
  "quantity": 5,
  "price": 1500,
  "target_price": 1600,
  "stop_loss_price": 1400,
  "trailing_jump": 10
}
```

#### Parameters

| Field              | Type                     | Description                                                                                                                                                                     |
| ------------------ | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dhan_client_id`   | string *(required)*      | User specific identification generated by Dhan. When you call through `DhanHQ::Models::SuperOrder`, the gem injects your configured client id so you can omit this key locally. |
| `correlation_id`   | string                   | Caller generated correlation identifier                                                                                                                                         |
| `transaction_type` | enum string *(required)* | Trading side. `BUY` or `SELL`.                                                                                                                                                  |
| `exchange_segment` | enum string *(required)* | Exchange segment (see appendix).                                                                                                                                                |
| `product_type`     | enum string *(required)* | Product type. `CNC`, `INTRADAY`, `MARGIN`, or `MTF`.                                                                                                                            |
| `order_type`       | enum string *(required)* | Order type. `LIMIT` or `MARKET`.                                                                                                                                                |
| `security_id`      | string *(required)*      | Exchange standard security identifier.                                                                                                                                          |
| `quantity`         | integer *(required)*     | Number of shares for the order.                                                                                                                                                 |
| `price`            | float *(required)*       | Price at which the entry leg is placed.                                                                                                                                         |
| `target_price`     | float *(required)*       | Target price for the super order.                                                                                                                                               |
| `stop_loss_price`  | float *(required)*       | Stop-loss price for the super order.                                                                                                                                            |
| `trailing_jump`    | float *(required)*       | Price jump size used to trail the stop-loss.                                                                                                                                    |

> 🐍 When you call `DhanHQ::Models::SuperOrder.create`, pass snake_case keys as shown above. The client automatically camelizes
> them before posting to Dhan's REST API and injects your configured `dhan_client_id`, so you can omit that key in Ruby code.

#### Response

```json
{
  "order_id": "112111182198",
  "order_status": "PENDING"
}
```

| Field          | Type        | Description                                         |
| -------------- | ----------- | --------------------------------------------------- |
| `order_id`     | string      | Order identifier generated by Dhan                  |
| `order_status` | enum string | Latest status. `TRANSIT`, `PENDING`, or `REJECTED`. |

### Modify Super Order

Use the modify endpoint to update any leg while the super order remains in `PENDING` or `PART_TRADED` status.

> ℹ️ Static IP whitelisting with Dhan support is required before invoking this API.

```bash
curl --request PUT \
  --url https://api.dhan.co/v2/super/orders/{order_id} \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT' \
  --data '{Request JSON}'
```

#### Request body

```json
{
  "dhan_client_id": "1000000009",
  "order_id": "112111182045",
  "order_type": "LIMIT",
  "leg_name": "ENTRY_LEG",
  "quantity": 40,
  "price": 1300,
  "target_price": 1450,
  "stop_loss_price": 1350,
  "trailing_jump": 20
}
```

#### Parameters

| Field             | Type                                   | Description                                                                                                               |
| ----------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `dhan_client_id`  | string *(required)*                    | User specific identification generated by Dhan. Automatically added when you call through the Ruby models.                |
| `order_id`        | string *(required)*                    | Super order identifier generated by Dhan.                                                                                 |
| `order_type`      | enum string *(conditionally required)* | `LIMIT` or `MARKET`. Required when modifying `ENTRY_LEG`.                                                                 |
| `leg_name`        | enum string *(required)*               | `ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`. Entry leg updates entire order while status is `PENDING` or `PART_TRADED`. |
| `quantity`        | integer *(conditionally required)*     | Quantity update for `ENTRY_LEG`.                                                                                          |
| `price`           | float *(conditionally required)*       | Entry price update for `ENTRY_LEG`.                                                                                       |
| `target_price`    | float *(conditionally required)*       | Target price update for `ENTRY_LEG` or `TARGET_LEG`.                                                                      |
| `stop_loss_price` | float *(conditionally required)*       | Stop-loss price update for `ENTRY_LEG` or `STOP_LOSS_LEG`.                                                                |
| `trailing_jump`   | float *(conditionally required)*       | Trailing jump update for `ENTRY_LEG` or `STOP_LOSS_LEG`. Omit or set to `0` to cancel trailing.                           |

> ℹ️ Once the entry leg status becomes `TRADED`, only the `TARGET_LEG` and `STOP_LOSS_LEG` can be modified (price and trailing jump).

#### Response

```json
{
  "order_id": "112111182045",
  "order_status": "TRANSIT"
}
```

| Field          | Type        | Description                                                   |
| -------------- | ----------- | ------------------------------------------------------------- |
| `order_id`     | string      | Order identifier generated by Dhan                            |
| `order_status` | enum string | Latest status. `TRANSIT`, `PENDING`, `REJECTED`, or `TRADED`. |

### Cancel Super Order

Cancel a pending or active super order leg using the order ID. Cancelling the entry leg removes every leg. Cancelling a specific target or stop-loss leg removes only that leg and it cannot be re-added.

> ℹ️ Static IP whitelisting with Dhan support is required before invoking this API.

```bash
curl --request DELETE \
  --url https://api.dhan.co/v2/super/orders/{order_id}/{order_leg} \
  --header 'Content-Type: application/json' \
  --header 'access-token: JWT'
```

#### Path parameters

| Field       | Description                                                   | Example       |
| ----------- | ------------------------------------------------------------- | ------------- |
| `order_id`  | Super order identifier.                                       | `11211182198` |
| `order_leg` | Leg to cancel. `ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`. | `ENTRY_LEG`   |

#### Response

```json
{
  "order_id": "112111182045",
  "order_status": "CANCELLED"
}
```

| Field          | Type        | Description                                                      |
| -------------- | ----------- | ---------------------------------------------------------------- |
| `order_id`     | string      | Order identifier generated by Dhan                               |
| `order_status` | enum string | Latest status. `TRANSIT`, `PENDING`, `REJECTED`, or `CANCELLED`. |

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
    "dhan_client_id": "1100003626",
    "order_id": "5925022734212",
    "correlation_id": "string",
    "order_status": "PENDING",
    "transaction_type": "BUY",
    "exchange_segment": "NSE_EQ",
    "product_type": "CNC",
    "order_type": "LIMIT",
    "validity": "DAY",
    "trading_symbol": "HDFCBANK",
    "security_id": "1333",
    "quantity": 10,
    "remaining_quantity": 10,
    "ltp": 1660.95,
    "price": 1500,
    "after_market_order": false,
    "leg_name": "ENTRY_LEG",
    "exchange_order_id": "11925022734212",
    "create_time": "2025-02-27 19:09:42",
    "update_time": "2025-02-27 19:09:42",
    "exchange_time": "2025-02-27 19:09:42",
    "oms_error_description": "",
    "average_traded_price": 0,
    "filled_qty": 0,
    "leg_details": [
      {
        "order_id": "5925022734212",
        "leg_name": "STOP_LOSS_LEG",
        "transaction_type": "SELL",
        "total_quantity": 0,
        "remaining_quantity": 0,
        "triggered_quantity": 0,
        "price": 1400,
        "order_status": "PENDING",
        "trailing_jump": 10
      },
      {
        "order_id": "5925022734212",
        "leg_name": "TARGET_LEG",
        "transaction_type": "SELL",
        "remaining_quantity": 0,
        "triggered_quantity": 0,
        "price": 1550,
        "order_status": "PENDING",
        "trailing_jump": 0
      }
    ]
  }
]
```

#### Parameters

| Field                   | Type        | Description                                                                                         |
| ----------------------- | ----------- | --------------------------------------------------------------------------------------------------- |
| `dhan_client_id`        | string      | User specific identification generated by Dhan.                                                     |
| `order_id`              | string      | Order identifier generated by Dhan.                                                                 |
| `correlation_id`        | string      | Correlation identifier supplied by the caller.                                                      |
| `order_status`          | enum string | Latest status. `TRANSIT`, `PENDING`, `CLOSED`, `REJECTED`, `CANCELLED`, `PART_TRADED`, or `TRADED`. |
| `transaction_type`      | enum string | Trading side. `BUY` or `SELL`.                                                                      |
| `exchange_segment`      | enum string | Exchange segment.                                                                                   |
| `product_type`          | enum string | Product type. `CNC`, `INTRADAY`, `MARGIN`, or `MTF`.                                                |
| `order_type`            | enum string | Order type. `LIMIT` or `MARKET`.                                                                    |
| `validity`              | enum string | Order validity. `DAY`.                                                                              |
| `trading_symbol`        | string      | Trading symbol reference.                                                                           |
| `security_id`           | string      | Exchange security identifier.                                                                       |
| `quantity`              | integer     | Ordered quantity.                                                                                   |
| `remaining_quantity`    | integer     | Quantity pending execution.                                                                         |
| `ltp`                   | float       | Last traded price.                                                                                  |
| `price`                 | float       | Order price.                                                                                        |
| `after_market_order`    | boolean     | Indicates if the order was placed after market hours.                                               |
| `leg_name`              | enum string | Leg identifier: `ENTRY_LEG`, `TARGET_LEG`, or `STOP_LOSS_LEG`.                                      |
| `trailing_jump`         | float       | Trailing jump for stop-loss.                                                                        |
| `exchange_order_id`     | string      | Exchange-generated order identifier.                                                                |
| `create_time`           | string      | Order creation timestamp.                                                                           |
| `update_time`           | string      | Latest update timestamp.                                                                            |
| `exchange_time`         | string      | Exchange timestamp.                                                                                 |
| `oms_error_description` | string      | OMS error description when applicable.                                                              |
| `average_traded_price`  | float       | Average traded price.                                                                               |
| `filled_qty`            | integer     | Quantity traded on the exchange.                                                                    |
| `triggered_quantity`    | integer     | Quantity triggered for stop-loss or target legs.                                                    |
| `leg_details`           | array       | Nested leg details for the super order.                                                             |

> ✅ `CLOSED` indicates the entry leg plus either target or stop-loss leg completed for the entire quantity. `TRIGGERED` appears on target and stop-loss legs to show which leg fired; inspect `triggered_quantity` for the executed quantity.

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
