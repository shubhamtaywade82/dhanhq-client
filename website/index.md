---
title: DhanHQ Ruby SDK — Dhan API Client for Ruby & Rails
description: Production-grade Ruby gem for Dhan API v2 with WebSocket market data, typed models, dry-validation contracts and Rails integration for algorithmic trading on NSE, BSE and MCX.
---

# DhanHQ <small>Ruby SDK for Dhan API v2</small>

A production-grade **Ruby gem** for the [Dhan trading API](https://dhanhq.co/docs/v2/). Build algorithmic trading systems, market data pipelines, and portfolio management tools for Indian markets (NSE, BSE, MCX) with clean Ruby abstractions, resilient WebSocket streaming, typed models, and safety-focused order workflows.

## Quick Start

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

# Fetch positions
positions = DhanHQ::Models::Position.all
```

## Features

- **Typed models** for orders, positions, holdings, funds, and trades
- **WebSocket market feed** with auto-reconnect and exponential backoff
- **WebSocket order updates** — real-time execution events
- **Token lifecycle management** with automatic retry-on-401
- **dry-validation contracts** for every trading request
- **Rails integration** with ActionCable, config generators, and rake tasks
- **Safety rails** — validation before transport, no blind retries
- **REST API** — orders, super orders, positions, holdings, funds, instruments, option chain, historical data, and more

## Next Steps

| Guide | Description |
|-------|-------------|
| [Installation & Setup](/getting-started) | Configure the gem and authenticate |
| [Orders API](/api/orders) | Place, modify, cancel orders |
| [WebSocket Market Feed](/websocket/market-feed) | Stream live market data |
| [Rails Integration](/rails) | Use DhanHQ with Ruby on Rails |
| [Technical Analysis](/analytics/technical-analysis) | Built-in indicator helpers |
| [GitHub](https://github.com/shubhamtaywade82/dhanhq-client) | Source code and issues |
| [RubyGems](https://rubygems.org/gems/DhanHQ) | Gem registry |

<hr />

<div class="disclaimer">

**Community project.** This is an independent gem and is not affiliated with, endorsed by, or supported by Dhan.

</div>
