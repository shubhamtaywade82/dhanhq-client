# Dhan API Ruby Examples

This page collects small, direct examples for people searching for `Dhan API Ruby`, `Ruby SDK for Dhan API examples`, or `Dhan trading SDK for Ruby`.

All examples use `DhanHQ`, the Ruby SDK for Dhan API v2.

## Setup

```ruby
require "dhan_hq"

DhanHQ.configure_with_env
```

## Example: Get Positions In Ruby

```ruby
# Example: Fetch positions using Dhan API in Ruby
positions = DhanHQ::Models::Position.all
```

## Example: Get Holdings In Ruby

```ruby
# Example: Fetch holdings using Dhan API in Ruby
holdings = DhanHQ::Models::Holding.all
```

## Example: Fetch Historical Data In Ruby

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

## Example: Subscribe To Live Market Data In Ruby

```ruby
# Example: Subscribe to live market data using Dhan API WebSocket in Ruby
client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  puts "#{tick[:security_id]} -> #{tick[:ltp]}"
end
```

## Example: Build An Order Payload In Ruby

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
```

## Where To Go Next

- [README.md](../README.md)
- [HOW_TO_USE_DHAN_API_WITH_RUBY.md](HOW_TO_USE_DHAN_API_WITH_RUBY.md)
- [examples/portfolio_monitor.rb](../examples/portfolio_monitor.rb)
- [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb)
- [examples/options_watchlist.rb](../examples/options_watchlist.rb)
