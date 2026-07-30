---
title: DhanHQ for Ruby on Rails — Dhan API Integration
description: Integrate the DhanHQ Ruby gem with Ruby on Rails. ActionCable WebSocket integration, config generators, rake tasks, and background job patterns.
---

# Rails Integration

DhanHQ provides first-class Rails integration for building trading dashboards, portfolio trackers, and automated trading systems.

## Manual Setup

Create `config/initializers/dhan_hq.rb`:

```ruby
DhanHQ.configure do |c|
  c.client_id    = ENV["DHAN_CLIENT_ID"]
  c.access_token = ENV["DHAN_ACCESS_TOKEN"]
end
```

## ActionCable Integration

Stream real-time market data and order updates to the browser via ActionCable:

```ruby
# app/channels/market_data_channel.rb
class MarketDataChannel < ApplicationCable::Channel
  def subscribed
    stream_from "market_data_#{params[:security_id]}"
  end
end
```

```ruby
# A background job feeding WebSocket data to ActionCable
ws_client = DhanHQ::WS::Client.new(mode: :ticker)
ws_client.start

ws_client.on(:tick) do |tick|
  ActionCable.server.broadcast(
    "market_data_#{tick[:security_id]}",
    tick
  )
end
```

## Background Jobs

Use DhanHQ WebSocket clients in Rails background jobs for long-running market data and order monitoring processes.

See the full [Rails Integration guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/RAILS_INTEGRATION.md) on GitHub.
