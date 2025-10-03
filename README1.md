# DhanHQ - Ruby Client for DhanHQ API

DhanHQ is a **Ruby client** for interacting with **Dhan API v2.0**. It provides **ActiveRecord-like** behavior, **RESTful resource management**, and **ActiveModel validation** for seamless integration into **algorithmic trading applications**.

## ⚡ Features

✅ **ORM-like Interface** (`find`, `all`, `where`, `save`, `update`, `destroy`)
✅ **ActiveModel Integration** (`validations`, `errors`, `serialization`)
✅ **Resource Objects for Trading** (`Orders`, `Positions`, `Holdings`, etc.)
✅ **Supports WebSockets for Market Feeds**
✅ **Error Handling & Validations** (`ActiveModel::Errors`)
✅ **DRY & Modular Code** (`Helpers`, `Contracts`, `Request Handling`)

---

## 📌 Installation

Add this line to your application's Gemfile:

```ruby
gem 'DhanHQ', git: 'https://github.com/shubhamtaywade82/dhanhq-client.git', branch: 'main'
```

Then execute:

```
bundle install
```

Or install it manually:

```
gem install dhanhq
```

🔹 Configuration
Set your DhanHQ API credentials:

```ruby
require 'DhanHQ'

DhanHQ.configure do |config|
  config.client_id = "your_client_id"
  config.access_token = "your_access_token"
  # Optional: override the default API endpoint
  config.base_url = "https://api.dhan.co/v2"
end
```

Use `config.base_url` to point the client at a different API URL (for example, a sandbox).

Alternatively, set credentials from environment variables:

```ruby
require 'DhanHQ'

DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }
```

`configure_with_env` expects the following environment variables:

* `CLIENT_ID`
* `ACCESS_TOKEN`
* `DHAN_LOG_LEVEL` (optional, defaults to `INFO`)

Create a `.env` file in your project root to supply these values:

```dotenv
CLIENT_ID=your_client_id
ACCESS_TOKEN=your_access_token
```

The gem requires `dotenv/load`, so these variables are loaded automatically when you require `DhanHQ`.

## 🚀 Usage

✅ Placing an Order

```ruby
order = DhanHQ::Models::Order.new(
  transaction_type: "BUY",
  exchange_segment: "NSE_FNO",
  product_type: "MARGIN",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "43492",
  quantity: 125,
  price: 100.0
)

order.save
puts order.persisted? # true
```

✅ Fetching an Order

```ruby
order = DhanHQ::Models::Order.find("452501297117")
puts order.price # Current price of the order
```

✅ Updating an Order

```ruby
order.update(price: 105.0)
puts order.price # 105.0
```

✅ Canceling an Order

```ruby
order.cancel
```

✅ Fetching All Orders

```ruby
orders = DhanHQ::Models::Order.all
puts orders.count
```

✅ Querying Orders

```ruby
pending_orders = DhanHQ::Models::Order.where(status: "PENDING")
puts pending_orders.first.order_id
```

✅ Exiting Positions

```ruby
positions = DhanHQ::Models::Position.all
position = positions.first
position.exit!
```

### Orders

#### Place

```ruby
order = DhanHQ::Models::Order.new(transaction_type: "BUY", security_id: "123", quantity: 1)
order.save
```

#### Modify

```ruby
order.modify(price: 102.5)
```

#### Cancel

```ruby
order.cancel
```

### Trades

```ruby
DhanHQ::Models::Trade.today
DhanHQ::Models::Trade.find_by_order_id("452501297117")
```

### Positions

```ruby
positions = DhanHQ::Models::Position.all
active = DhanHQ::Models::Position.active
DhanHQ::Models::Position.convert(position_id: "1", product_type: "CNC")
```

### Holdings

```ruby
DhanHQ::Models::Holding.all
```

### Funds

```ruby
DhanHQ::Models::Funds.fetch
balance = DhanHQ::Models::Funds.balance
```

### Option Chain

```ruby
DhanHQ::Models::OptionChain.fetch(security_id: "1333", expiry_date: "2024-06-30")
DhanHQ::Models::OptionChain.fetch_expiry_list(security_id: "1333")
```

### Historical Data

```ruby
DhanHQ::Models::HistoricalData.daily(security_id: "1333", from_date: "2024-01-01", to_date: "2024-01-31")
DhanHQ::Models::HistoricalData.intraday(security_id: "1333", interval: "15")
```

## 🔹 Available Resources

| Resource                 | Model                            | Actions                                             |
| ------------------------ | -------------------------------- | --------------------------------------------------- |
| Orders                   | `DhanHQ::Models::Models::Order`          | `find`, `all`, `where`, `place`, `update`, `cancel` |
| Trades                   | `DhanHQ::Models::Models::Trade`          | `all`, `find_by_order_id`                           |
| Forever Orders           | `DhanHQ::Models::Models::ForeverOrder`   | `create`, `find`, `modify`, `cancel`, `all`         |
| Holdings                 | `DhanHQ::Models::Models::Holding`        | `all`                                               |
| Positions                | `DhanHQ::Models::Models::Position`       | `all`, `find`, `exit!`                              |
| Funds & Margin           | `DhanHQ::Models::Models::Funds`          | `fund_limit`, `margin_calculator`                   |
| Ledger                   | `DhanHQ::Models::Models::Ledger`         | `all`                                               |
| Market Feeds             | `DhanHQ::Models::Models::MarketFeed`     | `ltp, ohlc`, `quote`                                |
| Historical Data (Charts) | `DhanHQ::Models::Models::HistoricalData` | `daily`, `intraday`                                 |
| Option Chain             | `DhanHQ::Models::Models::OptionChain`    | `fetch`, `fetch_expiry_list`                        |

## 📌 Development

Set `DHAN_DEBUG=true` to log HTTP requests during development:

```bash
export DHAN_DEBUG=true
```

Running Tests

```bash
bundle exec rspec
```

Installing Locally

```bash
bundle exec rake install
```

Releasing a New Version

```bash
bundle exec rake release
```
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

## Super Orders (example)

```ruby
intent = {
  exchange_segment: "NSE_FNO",
  security_id:      "12345",   # option
  transaction_type: "BUY",
  quantity:         50,
  # derived risk params from ATR/ADX
  take_profit:      0.35,      # 35% target
  stop_loss:        0.18,      # 18% SL
  trailing_sl:      0.12       # 12% trail
}

# If your SuperOrder model exposes create/modify:
o = DhanHQ::Models::SuperOrder.create(intent)
# or fallback:
mkt = DhanHQ::Models::Order.new(
  transaction_type: "BUY", exchange_segment: "NSE_FNO",
  order_type: "MARKET", validity: "DAY",
  security_id: "12345", quantity: 50
).save
```

If you placed a Super Order and want to trail SL upward using WS ticks:

```ruby
DhanHQ::Models::SuperOrder.modify(
  order_id: o.order_id,
  stop_loss: new_abs_price,    # broker API permitting
  trailing_sl: nil
)
```

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


## 📌 Contributing

Bug reports and pull requests are welcome on GitHub at:
🔗 <https://github.com/shubhamtaywade82/dhanhq>

This project follows a code of conduct to maintain a safe and welcoming community.

## 📌 License

This gem is available under the MIT License.
🔗 <https://opensource.org/licenses/MIT>

## 📌 Code of Conduct

Everyone interacting in the DhanHQ project is expected to follow the
🔗 Code of Conduct.

```markdown
This **README.md** file is structured and formatted for **GitHub** or any **Markdown-compatible** documentation system. 🚀
```
