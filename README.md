# DhanHQ — Ruby Client for Dhan API v2

[![Gem Version](https://badge.fury.io/rb/DhanHQ.svg)](https://rubygems.org/gems/DhanHQ)
[![CI](https://github.com/shubhamtaywade82/dhanhq-client/actions/workflows/main.yml/badge.svg)](https://github.com/shubhamtaywade82/dhanhq-client/actions/workflows/main.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-ruby.svg)](https://www.ruby-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE.txt)

A production-grade Ruby SDK for the [Dhan trading API](https://dhanhq.co/docs/v2/) — ORM-like models, WebSocket market feeds, and battle-tested reliability for real trading.

## 🚀 60-Second Quick Start

```ruby
# Gemfile
gem 'DhanHQ'
```

```ruby
require 'dhan_hq'

DhanHQ.configure do |c|
  c.client_id    = ENV["DHAN_CLIENT_ID"]
  c.access_token = ENV["DHAN_ACCESS_TOKEN"]
end

# You're live
positions = DhanHQ::Models::Position.all
holdings  = DhanHQ::Models::Holding.all
```

---

## Why DhanHQ?

You could wire up Faraday and parse JSON yourself. Here's why you shouldn't:

| You get                        | Instead of                                    |
| ------------------------------ | --------------------------------------------- |
| ActiveModel-style `find`, `all`, `save`, `cancel` | Manual HTTP + JSON wrangling          |
| Typed models with validations  | Hash soup and runtime surprises               |
| Auto token refresh + retry-on-401 | Silent auth failures at 3 AM               |
| WebSocket reconnection with backoff | Dropped connections during volatile moves |
| 429 rate-limit cool-off        | Getting banned by the exchange                |
| Thread-safe, secure logging    | Leaked tokens in production logs              |

---

## ✨ Key Features

- **ActiveRecord-style models** — `find`, `all`, `where`, `save`, `cancel` across Orders, Positions, Holdings, Funds, and more
- **Auto token refresh** — 401 retry with fresh token via provider callback
- **Thread-safe WebSocket client** — Orders, Market Feed, Market Depth with auto-reconnect
- **Exponential backoff + 429 cool-off** — no manual rate-limit management
- **Secure logging** — automatic token sanitization in all log output
- **Super Orders** — entry + stop-loss + target + trailing jump in one request
- **Instrument convenience methods** — `.ltp`, `.ohlc`, `.option_chain` directly on instruments
- **Full REST coverage** — Orders, Trades, Forever Orders, Super Orders, Positions, Holdings, Funds, HistoricalData, OptionChain, MarketFeed, EDIS, Kill Switch, P&L Exit, Alert Orders, Margin Calculator
- **P&L Based Exit** — automatic position exit on profit/loss thresholds
- **Postback parser** — parse Dhan webhook payloads with `Postback.parse` and status predicates
- **EDIS model** — ORM-style T-PIN, form, and status inquiry for delivery instruction slips

---

## Installation

```ruby
# Gemfile (recommended)
gem 'DhanHQ'
```

```bash
bundle install
# or
gem install DhanHQ
```

> **Bleeding edge?** Use `gem 'DhanHQ', git: 'https://github.com/shubhamtaywade82/dhanhq-client.git', branch: 'main'` only if you need unreleased features.

### ⚠️ Breaking Change (v2.1.5+)

The require statement changed:

```ruby
# Before         # Now
require 'DhanHQ'  →  require 'dhan_hq'
```

The gem name in your Gemfile stays `DhanHQ` — only the `require` changes.

---

## Configuration

### Static token (simplest)

```ruby
require 'dhan_hq'
DhanHQ.configure_with_env   # reads DHAN_CLIENT_ID + DHAN_ACCESS_TOKEN from ENV
```

| Variable             | Purpose                                |
| -------------------- | -------------------------------------- |
| `DHAN_CLIENT_ID`     | Your Dhan trading account client ID    |
| `DHAN_ACCESS_TOKEN`  | API token from the Dhan console        |

### Dynamic token (production / OAuth)

```ruby
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"]
  config.access_token_provider = -> { YourTokenStore.active_token }
  config.on_token_expired = ->(error) { YourTokenStore.refresh! }  # optional
end
```

When the API returns 401, the client retries **once** with a fresh token from your provider.

> **Full details**: TOTP flows, partner mode, token endpoint bootstrap, auto-management — see [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md).

---

## REST API

### Orders — Place, Modify, Cancel

```ruby
order = DhanHQ::Models::Order.new(
  transaction_type: "BUY",
  exchange_segment: "NSE_FNO",
  product_type:     "MARGIN",
  order_type:       "LIMIT",
  validity:         "DAY",
  security_id:      "43492",
  quantity:         50,
  price:            100.0
)
order.save          # places the order
order.modify(price: 101.5)
order.cancel
```

### Positions, Holdings, Funds

```ruby
DhanHQ::Models::Position.all
DhanHQ::Models::Holding.all
DhanHQ::Models::Fund.balance
```

### Historical Data

```ruby
bars = DhanHQ::Models::HistoricalData.intraday(
  security_id:      "13",
  exchange_segment: "IDX_I",
  instrument:       "INDEX",
  interval:         "5",
  from_date:        "2025-08-14",
  to_date:          "2025-08-18"
)
```

### Instrument Lookup

```ruby
nifty = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")
nifty.ltp           # last traded price
nifty.ohlc          # OHLC data
nifty.option_chain(expiry: "2025-02-28")
nifty.intraday(from_date: "2025-08-14", to_date: "2025-08-18", interval: "15")
```

---

## WebSockets

Three real-time feeds, all with **auto-reconnect**, **backoff**, **429 cool-off**, and **thread-safe operation**.

### Order Updates

```ruby
DhanHQ::WS::Orders.connect do |order_update|
  puts "#{order_update.order_no} → #{order_update.status} (#{order_update.traded_qty}/#{order_update.quantity})"
end
```

### Market Feed (Ticker / Quote / Full)

```ruby
client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  puts "#{tick[:security_id]} = ₹#{tick[:ltp]}"
end

client.subscribe_one(segment: "IDX_I", security_id: "13")   # NIFTY
client.subscribe_one(segment: "IDX_I", security_id: "25")   # BANKNIFTY
```

### Market Depth

```ruby
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")

DhanHQ::WS::MarketDepth.connect(symbols: [
  { symbol: "RELIANCE", exchange_segment: reliance.exchange_segment, security_id: reliance.security_id }
]) do |depth|
  puts "Best Bid: #{depth[:best_bid]} | Best Ask: #{depth[:best_ask]} | Spread: #{depth[:spread]}"
end
```

### Cleanup

```ruby
DhanHQ::WS.disconnect_all_local!   # kills all local WS connections
```

---

## Super Orders

Entry + target + stop-loss + trailing jump in a single request:

```ruby
DhanHQ::Models::SuperOrder.create(
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type:     "CNC",
  order_type:       "LIMIT",
  security_id:      "11536",
  quantity:         5,
  price:            1500,
  target_price:     1600,
  stop_loss_price:  1400,
  trailing_jump:    10
)
```

> **Full API reference** (modify, cancel, list, response schemas): [docs/SUPER_ORDERS.md](docs/SUPER_ORDERS.md)

---

## Real-World Example: NIFTY Trend Monitor

```ruby
require 'dhan_hq'

DhanHQ.configure_with_env

# 1. Check the trend using historical 5-min bars
bars = DhanHQ::Models::HistoricalData.intraday(
  security_id: "13", exchange_segment: "IDX_I",
  instrument: "INDEX", interval: "5",
  from_date: Date.today.to_s, to_date: Date.today.to_s
)

closes = bars.map { |b| b[:close] }
sma_20 = closes.last(20).sum / 20.0
trend  = closes.last > sma_20 ? :bullish : :bearish
puts "NIFTY trend: #{trend} (LTP: #{closes.last}, SMA20: #{sma_20.round(2)})"

# 2. Stream live ticks for real-time monitoring
client = DhanHQ::WS.connect(mode: :quote) do |tick|
  puts "NIFTY ₹#{tick[:ltp]} | Vol: #{tick[:vol]} | #{Time.now.strftime('%H:%M:%S')}"
end
client.subscribe_one(segment: "IDX_I", security_id: "13")

# 3. On signal, place a super order with built-in risk management
# DhanHQ::Models::SuperOrder.create(
#   transaction_type: "BUY", exchange_segment: "NSE_FNO", ...
#   target_price: entry + 50, stop_loss_price: entry - 30, trailing_jump: 5
# )

# 4. Clean shutdown
at_exit { DhanHQ::WS.disconnect_all_local! }
sleep   # keep the script alive
```

---

## Rails Integration

Need initializers, service objects, ActionCable wiring, and background workers? See the [Rails Integration Guide](docs/RAILS_INTEGRATION.md).

---

## 📚 Documentation

| Guide | What it covers |
| ----- | -------------- |
| [Authentication](docs/AUTHENTICATION.md) | Token flows, TOTP, OAuth, auto-management |
| [Configuration Reference](docs/CONFIGURATION.md) | Full ENV matrix, logging, timeouts, available resources |
| [WebSocket Integration](docs/WEBSOCKET_INTEGRATION.md) | All WS types, architecture, best practices |
| [WebSocket Protocol](docs/WEBSOCKET_PROTOCOL.md) | Packet parsing, request codes, tick schema, exchange enums |
| [Rails WebSocket Guide](docs/RAILS_WEBSOCKET_INTEGRATION.md) | Rails-specific patterns, ActionCable |
| [Rails Integration](docs/RAILS_INTEGRATION.md) | Initializers, service objects, workers |
| [Standalone Ruby Guide](docs/STANDALONE_RUBY_WEBSOCKET_INTEGRATION.md) | Scripts, daemons, CLI tools |
| [Super Orders API](docs/SUPER_ORDERS.md) | Full REST reference for super orders |
| [API Constants Reference](docs/CONSTANTS_REFERENCE.md) | All valid enums, exchange segments, and order parameters |
| [Data API Parameters](docs/DATA_API_PARAMETERS.md) | Historical data, option chain parameters |
| [Testing Guide](docs/TESTING_GUIDE.md) | WebSocket testing, model testing, console helpers |
| [Technical Analysis](docs/TECHNICAL_ANALYSIS.md) | Indicators, multi-timeframe aggregation |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | 429 errors, reconnect, auth issues, debug logging |
| [Release Guide](docs/RELEASE_GUIDE.md) | Versioning, publishing, changelog |

---

## Best Practices

- Keep `on(:tick)` handlers **non-blocking** — push heavy work to a queue/thread
- Use `mode: :quote` for most strategies; `:full` only if you need depth/OI
- Don't exceed **100 instruments per subscribe frame** (auto-chunked by the client)
- Call `DhanHQ::WS.disconnect_all_local!` on shutdown
- Avoid rapid connect/disconnect loops — the client already backs off on 429

---

## Contributing

PRs welcome! Please include tests for new features. See [CHANGELOG.md](CHANGELOG.md) for recent changes.

```bash
bundle exec rake          # run tests
bundle exec rubocop       # lint
bin/console               # interactive console
```

## License

[MIT](LICENSE.txt)
