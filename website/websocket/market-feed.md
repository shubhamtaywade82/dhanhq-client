---
title: Dhan WebSocket Market Feed — Ruby SDK & Client
description: Stream real-time market data (LTP, OHLCV, depth) over WebSocket with the DhanHQ Ruby gem. Auto-reconnect and binary packet parsing.
---

# WebSocket Market Feed

Stream real-time LTP, OHLCV, and market depth over WebSocket with auto-reconnect and exponential backoff.

## Connection

```ruby
client = DhanHQ::WS::Client.new(mode: :ticker)
client.start

client.subscribe_many([
  { exchange_segment: "NSE_EQ", security_id: "1333" },
  { exchange_segment: "NSE_FNO", security_id: "58072" },
  { exchange_segment: "IDX_I", security_id: "13" }
])

client.on(:tick) do |tick|
  puts "#{tick[:exchange_segment]}:#{tick[:security_id]} LTP=#{tick[:ltp]}"
end

client.on(:reconnect) do |info|
  puts "Reconnected (attempt #{info[:attempt]})"
end
```

## Unsubscribe

```ruby
client.unsubscribe_one(segment: "NSE_EQ", security_id: "1333")
```

See the [WebSocket Integration guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/WEBSOCKET_INTEGRATION.md) for full documentation.
