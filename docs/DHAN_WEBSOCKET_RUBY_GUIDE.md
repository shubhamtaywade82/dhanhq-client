# Dhan WebSocket Ruby Guide

If you are searching for `Dhan WebSocket Ruby`, `Dhan API WebSocket in Ruby`, or `Ruby SDK for Dhan market data streaming`, this is the shortest path.

`DhanHQ` provides the WebSocket layer for Ruby applications that need live market data, market depth, and order updates without rebuilding reconnect and rate-limit handling from scratch.

## Basic Market Feed Example

```ruby
require "dhan_hq"

DhanHQ.configure_with_env

# Example: Subscribe to live market data using Dhan API WebSocket in Ruby
client = DhanHQ::WS.connect(mode: :quote) do |tick|
  puts "#{tick[:security_id]} -> #{tick[:ltp]}"
end

client.subscribe_one(
  segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
  security_id: "13"
)
```

## Why Use The SDK For Dhan WebSockets In Ruby?

- auto-reconnect and backoff
- 429 cool-off handling
- dedicated order-update client
- market-depth support
- shared configuration with the rest of the Ruby SDK

## More Specific Paths

- Use [examples/options_watchlist.rb](../examples/options_watchlist.rb) for quote streaming with option-chain context
- Use [examples/live_order_updates.rb](../examples/live_order_updates.rb) for order lifecycle streaming
- Use [WEBSOCKET_INTEGRATION.md](WEBSOCKET_INTEGRATION.md) for the full Dhan WebSocket Ruby guide
- Use [WEBSOCKET_PROTOCOL.md](WEBSOCKET_PROTOCOL.md) for packet-level details
