# Quickstart

The five things most people need on day one. Everything here is copy-pasteable; deep dives live in [GUIDE.md](GUIDE.md), [ARCHITECTURE.md](ARCHITECTURE.md), and [docs/](docs/).

## 1. Install & configure

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
```

Rails app? Put the block in `config/initializers/dhanhq.rb` and read credentials via `Rails.application.credentials.dig(:dhanhq)` — see [docs/RAILS_INTEGRATION.md](docs/RAILS_INTEGRATION.md).

## 2. Read data (positions, holdings, funds)

```ruby
positions = DhanHQ::Models::Position.all
holdings  = DhanHQ::Models::Holding.all
funds     = DhanHQ::Models::Funds.fetch
```

No manual HTTP, no JSON wrangling — every response comes back as a typed model.

## 3. Place an order safely

Orders are blocked unless `ENV["LIVE_TRADING"]="true"` — set it deliberately, not by accident:

```ruby
order = DhanHQ::Models::Order.place(
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  product_type:     DhanHQ::Constants::ProductType::INTRADAY,
  order_type:       DhanHQ::Constants::OrderType::LIMIT,
  validity:         DhanHQ::Constants::Validity::DAY,
  security_id:      "11536",
  quantity:         5,
  price:            1500.0
)
```

Want an exception instead of an ambiguous falsy return on rejection? Use the bang variant: `Order.place!(...)` raises `DhanHQ::OrderError`. Before you're ready to trade live, set `config.dry_run = true` (or `DHAN_DRY_RUN=true`) to validate and log every write against real prices without sending it. See [Order Safety](README.md#order-safety) in the README.

## 4. Stream live prices

```ruby
client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  puts "#{tick[:security_id]} = ₹#{tick[:ltp]}"
end

client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::IDX_I, security_id: "13") # NIFTY
```

Reconnect, backoff, and re-subscription are automatic. Keep the tick handler non-blocking — push heavy work to a queue.

## 5. Build a strategy or bot

- Composable, non-executing strategies: `DhanHQ::Skills::Registry.find("iron_condor").call(symbol: "NIFTY", expiry: "2026-08-07")` — returns an intent hash, never places an order on its own. See the [Skills System](README.md#skills-system).
- Full worked example: [examples/basic_trading_bot.rb](examples/basic_trading_bot.rb).
- AI-agent access to the whole surface via MCP: `bundle exec dhanhq-mcp`. See [MCP Server](README.md#mcp-server-ai-agent-integration).

## Where to go next

| I want to... | Read |
|---|---|
| Understand the layers (BaseAPI, BaseModel, Resources, Contracts) | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Wire this into a Rails app end-to-end | [docs/RAILS_INTEGRATION.md](docs/RAILS_INTEGRATION.md) |
| Stream ticks into ActionCable | [docs/RAILS_WEBSOCKET_INTEGRATION.md](docs/RAILS_WEBSOCKET_INTEGRATION.md) |
| Understand the WebSocket wire protocol | [docs/WEBSOCKET_PROTOCOL.md](docs/WEBSOCKET_PROTOCOL.md) |
| Place Super Orders (entry + SL + target + trailing) | [docs/SUPER_ORDERS.md](docs/SUPER_ORDERS.md) |
| Set up auth (static token vs. dynamic provider) | [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md) |
| Write specs against this gem | [docs/TESTING_GUIDE.md](docs/TESTING_GUIDE.md) |
| Debug a stuck order or feed | [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| See every doc | [README.md § Documentation](README.md#-documentation) |
