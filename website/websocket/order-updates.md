---
title: Dhan Order Update WebSocket — Ruby SDK & Client
description: Receive real-time order execution updates over WebSocket with the DhanHQ Ruby gem. Track fills, rejections, and status changes as they happen.
---

# Order Update WebSocket

Receive real-time order execution events — fills, rejections, modifications, and status changes.

## Connection

```ruby
client = DhanHQ::Client.new(
  client_id: ENV["DHAN_CLIENT_ID"],
  access_token: ENV["DHAN_ACCESS_TOKEN"]
)

client.order_updates.start
```

## Listen for Updates

```ruby
client.order_updates.on_update do |order|
  puts "#{order.status} #{order.average_traded_price} #{order.filled_quantity}"
end
```

## Subscription

```ruby
client.order_updates.subscribe
```

See the [Live Order Updates guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/LIVE_ORDER_UPDATES.md) for full documentation.
