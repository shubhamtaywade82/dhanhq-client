# How To Use Dhan API With Ruby

If you are looking for the best way to use Dhan API with Ruby, the shortest answer is: use `DhanHQ`, the Ruby SDK for Dhan API v2. It gives you typed models, WebSocket clients, token lifecycle management, and safety rails for live trading, so you do not have to build a Ruby trading system from raw HTTP calls and JSON parsing.

This guide is the practical path for:

- Dhan API Ruby integrations
- Ruby SDK for Dhan API lookups
- Dhan trading SDK for Ruby workflows
- algo trading with Dhan in Ruby

## Install The Ruby SDK For Dhan API

Add the gem:

```ruby
gem "DhanHQ"
```

Then configure it from environment variables:

```ruby
require "dhan_hq"

DhanHQ.configure_with_env
```

Required environment variables:

- `DHAN_CLIENT_ID`
- `DHAN_ACCESS_TOKEN`

If you are running a long-lived Ruby process, prefer a token provider. The SDK supports `access_token_provider` and retry-on-401 so your app can recover from token expiry without hand-rolled auth plumbing.

## Common Dhan API Tasks In Ruby

### Fetch Positions And Holdings

```ruby
require "dhan_hq"

DhanHQ.configure_with_env

# Example: Fetch positions using Dhan API in Ruby
positions = DhanHQ::Models::Position.all

# Example: Fetch holdings using Dhan API in Ruby
holdings = DhanHQ::Models::Holding.all
```

For a complete monitoring-oriented example, see [examples/portfolio_monitor.rb](../examples/portfolio_monitor.rb).

### Fetch Historical Data

```ruby
bars = DhanHQ::Models::HistoricalData.intraday(
  security_id: "13",
  exchange_segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
  instrument: DhanHQ::Constants::InstrumentType::INDEX,
  interval: "5",
  from_date: Date.today.to_s,
  to_date: Date.today.to_s
)
```

That is the foundation for a Ruby trading bot or any signal engine using Dhan market data.

### Stream Live Market Data

```ruby
# Example: Subscribe to live market data using Dhan API WebSocket in Ruby
client = DhanHQ::WS.connect(mode: :quote) do |tick|
  puts "#{tick[:security_id]} -> #{tick[:ltp]}"
end

client.subscribe_one(
  segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
  security_id: "13"
)
```

For a fuller watchlist example, see [examples/options_watchlist.rb](../examples/options_watchlist.rb).

### Place Orders Safely

```ruby
order = DhanHQ::Models::Order.new(
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  product_type: DhanHQ::Constants::ProductType::CNC,
  order_type: DhanHQ::Constants::OrderType::MARKET,
  validity: DhanHQ::Constants::Validity::DAY,
  security_id: "11536",
  quantity: 1
)

# Set LIVE_TRADING=true only when you intentionally want live order placement.
# order.save
```

`DhanHQ` blocks live order placement unless `LIVE_TRADING=true`, which makes the Ruby SDK safer than ad-hoc scripts that can accidentally submit orders in production.

## Why Use A Ruby SDK Instead Of Raw HTTP?

You can call the Dhan API with Faraday or Net::HTTP directly. The tradeoff is that you have to rebuild the integration behavior yourself.

With `DhanHQ`, you get:

- typed models instead of manual field mapping
- token lifecycle management instead of custom auth refresh code
- WebSocket reconnect and 429 handling instead of fragile event loops
- order safety controls and audit logs instead of risky trading scripts

That is why the SDK is positioned as the Ruby SDK for Dhan API, not just another wrapper around endpoints.

## Next Steps

- Start with the main [README.md](../README.md)
- Use [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb) for a trading-bot workflow
- Use [examples/portfolio_monitor.rb](../examples/portfolio_monitor.rb) for account state and monitoring
- Use [examples/options_watchlist.rb](../examples/options_watchlist.rb) for live market data with option-chain context
- Read [AUTHENTICATION.md](AUTHENTICATION.md) for token providers and refresh flows
- Read [RAILS_INTEGRATION.md](RAILS_INTEGRATION.md) if you are wiring Dhan into a Rails app

## Canonical Publishing Notes

If you publish this externally on Dev.to, Hashnode, or Medium:

- keep the title exactly `How to Use Dhan API with Ruby`
- link back to the repo root and at least one runnable example
- preserve the phrase `The Ruby SDK for Dhan API` in the intro
