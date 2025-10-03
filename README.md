# DhanHQ — Ruby Client for DhanHQ API (v2)

A clean Ruby client for **Dhan API v2** with ORM-like models (Orders, Positions, Holdings, etc.) **and** a robust **WebSocket market feed** (ticker/quote/full) built on EventMachine + Faye.

* ActiveRecord-style models: `find`, `all`, `where`, `save`, `update`, `cancel`
* Validations & errors exposed via ActiveModel-like interfaces
* REST coverage: Orders, Super Orders, Forever Orders, Trades, Positions, Holdings, Funds/Margin, HistoricalData, OptionChain, MarketFeed
* **WebSocket**: subscribe/unsubscribe dynamically, auto-reconnect with backoff, 429 cool-off, idempotent subs, header+payload binary parsing, normalized ticks

---

## Installation

Add to your Gemfile:

```ruby
gem "DhanHQ"
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

### Programmatic

```ruby
require "DhanHQ"

DhanHQ.configure do |config|
  config.client_id    = ENV["CLIENT_ID"]    # e.g. "1001234567"
  config.access_token = ENV["ACCESS_TOKEN"] # e.g. "eyJhbGciOi..."
  # Optional REST base
  config.base_url     = "https://api.dhan.co/v2"
  # Optional WS version (default: 2)
  config.ws_version   = 2
  # Optional Order Update WS knobs
  config.ws_order_url  = "wss://api-order-update.dhan.co"
  config.ws_user_type  = "SELF"     # or "PARTNER"
  config.partner_id    = nil         # required for PARTNER mode
  config.partner_secret = nil
end
```

### From ENV / .env

```ruby
DhanHQ.configure_with_env
# expects:
#   CLIENT_ID=...
#   ACCESS_TOKEN=...
```

### Logging

```ruby
DhanHQ.logger.level = Logger::INFO  # or DEBUG for verbose
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
DhanHQ.logger.level = Logger::INFO

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
require "dhanhq"

DhanHQ.configure_with_env
DhanHQ.logger.level = Logger::INFO

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
   DhanHQ.logger.level = Logger::INFO
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
  Run with `DhanHQ.logger.level = Logger::DEBUG` to inspect; we safely drop malformed frames and keep the loop alive.

---

## Contributing

PRs welcome! Please include tests for new packet decoders and WS behaviors (chunking, reconnect, cool-off).

---

## License

MIT.
