---
title: Dhan WebSocket Market Feed — Ruby SDK & Client
description: Stream real-time market data (LTP, OHLCV, depth) over WebSocket with the DhanHQ Ruby gem. Auto-reconnect and binary packet parsing.
---

# WebSocket Market Feed

Stream real-time LTP, OHLCV, and market depth over WebSocket with auto-reconnect and exponential backoff.

## Connection

```ruby
client = DhanHQ::Client.new(
  client_id: ENV["DHAN_CLIENT_ID"],
  access_token: ENV["DHAN_ACCESS_TOKEN"]
)

client.market_feed.start
```

## Subscribe to Instruments

```ruby
client.market_feed.subscribe(
  [
    { exchange_segment: "NSE_EQ", security_id: "1333" },
    { exchange_segment: "NSE_FNO", security_id: "58072" },
    { exchange_segment: "IDX_I", security_id: "13" }
  ]
)
```

## Tick Events

```ruby
client.market_feed.on_tick do |tick|
  puts "#{tick.exchange_segment}:#{tick.security_id} LTP=#{tick.ltp}"
end
```

## Auto-Reconnect

The WebSocket client handles disconnections with exponential backoff:

```ruby
client.market_feed.on_reconnect do |attempt|
  puts "Reconnecting (attempt #{attempt})..."
end
```

## Unsubscribe

```ruby
client.market_feed.unsubscribe(
  [{ exchange_segment: "NSE_EQ", security_id: "1333" }]
)
```

See the [WebSocket Integration guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/WEBSOCKET_INTEGRATION.md) for full documentation.
