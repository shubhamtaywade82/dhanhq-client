---
title: DhanHQ for Ruby on Rails — Dhan API Integration
description: Integrate the DhanHQ Ruby gem with Ruby on Rails. ActionCable WebSocket integration, config generators, rake tasks, and background job patterns.
---

# Rails Integration

DhanHQ provides first-class Rails integration for building trading dashboards, portfolio trackers, and automated trading systems.

## Install Generator

```bash
rails generate dhan_hq:install
```

Creates:
- `config/initializers/dhan_hq.rb`
- Binstub for quick access

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
DhanHQ.market_feed.on_tick do |tick|
  ActionCable.server.broadcast(
    "market_data_#{tick.security_id}",
    tick.to_h
  )
end
```

## Rake Tasks

```bash
rails dhan_hq:positions    # Fetch current positions
rails dhan_hq:holdings     # Fetch current holdings
rails dhan_hq:funds        # Fetch fund limits
```

## Background Jobs

Use DhanHQ WebSocket clients in Rails background jobs for long-running market data and order monitoring processes.

See the full [Rails Integration guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/RAILS_INTEGRATION.md) on GitHub.
