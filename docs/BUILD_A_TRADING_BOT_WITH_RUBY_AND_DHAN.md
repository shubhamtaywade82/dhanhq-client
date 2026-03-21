# Build A Trading Bot With Ruby And Dhan

If your goal is to build a trading bot with Ruby and Dhan, you do not need to start from raw REST calls and custom WebSocket loops. `DhanHQ` is the Ruby SDK for Dhan API v2, and it already gives you the core pieces a Ruby trading bot needs: historical data access, live market data streaming, order models, token lifecycle handling, and live-trading guardrails.

This guide shows the minimal path from market data to signal to guarded execution.

## 1. Configure The SDK

```ruby
require "dhan_hq"

DhanHQ.configure_with_env
```

Set:

- `DHAN_CLIENT_ID`
- `DHAN_ACCESS_TOKEN`

Only set `LIVE_TRADING=true` when you intentionally want to place live orders.

## 2. Pull Historical Data For The Signal

Use the Dhan API from Ruby to fetch recent bars:

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

The runnable version of this flow lives in [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb).

## 3. Compute A Simple Trading Signal

```ruby
closes = bars.map { |bar| bar[:close].to_f }
last_close = closes.last
sma20 = closes.last(20).sum / 20.0
signal = last_close > sma20 ? :bullish : :bearish
```

This is intentionally simple. The point is not the strategy itself. The point is that the Ruby SDK for Dhan API gets you to a working trading loop quickly.

## 4. Add Live Market Data

Most trading bots need streaming updates after the initial historical snapshot.

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

For a fuller live-data script, see [examples/options_watchlist.rb](../examples/options_watchlist.rb).

## 5. Execute Safely

If the signal is bullish, you can build an order model:

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

# order.save
```

Keep `order.save` commented while you are developing. `DhanHQ` will only submit live orders when `LIVE_TRADING=true`, which is one of the reasons it is safer than raw order scripts.

## 6. Grow Into A Real Trading System

Once you have the basic bot loop, the same SDK supports:

- WebSocket order updates
- option-chain workflows
- Rails integration for service objects and workers
- token providers for long-running processes

Use these next:

- [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb)
- [examples/options_watchlist.rb](../examples/options_watchlist.rb)
- [WEBSOCKET_INTEGRATION.md](WEBSOCKET_INTEGRATION.md)
- [AUTHENTICATION.md](AUTHENTICATION.md)
- [RAILS_INTEGRATION.md](RAILS_INTEGRATION.md)

## Canonical Publishing Notes

If you publish this externally:

- keep the title exactly `Build a Trading Bot With Ruby and Dhan`
- link back to the repo root and the example scripts
- keep the intro sentence that frames `DhanHQ` as `the Ruby SDK for Dhan API`
