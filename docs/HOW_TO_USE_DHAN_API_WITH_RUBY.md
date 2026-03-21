# How To Use Dhan API With Ruby

This document is a repo-owned draft for a search-focused guide. Its job is to capture the questions users actually search for and route them into maintained project assets instead of ad-hoc snippets.

## Target Search Intent

- Dhan API Ruby
- Ruby SDK for Dhan API
- Dhan trading SDK for Ruby
- How to use Dhan API with Ruby

## Outline

### 1. What this gem is

Open with the category statement:

`DhanHQ is the Ruby SDK for Dhan API v2.`

Explain in one paragraph that it covers REST, WebSocket feeds, token refresh, and trading workflows for Ruby apps.

### 2. Install and configure

Use the shortest path:

```ruby
require "dhan_hq"

DhanHQ.configure_with_env
```

List required env vars:

- `DHAN_CLIENT_ID`
- `DHAN_ACCESS_TOKEN`

### 3. Common tasks

- Get positions and holdings
- Fetch historical data
- Stream live quotes
- Place orders safely with `LIVE_TRADING=true`

Link each task to the matching section in [README.md](../README.md) and to a concrete example in `examples/`.

### 4. Why use this over a thin wrapper

Keep the comparison factual:

- typed models
- auth lifecycle management
- WS reconnect and rate-limit handling
- Rails and standalone Ruby docs

### 5. Next steps

Route users to:

- [README.md](../README.md)
- [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb)
- [examples/portfolio_monitor.rb](../examples/portfolio_monitor.rb)
- [docs/AUTHENTICATION.md](AUTHENTICATION.md)
- [docs/RAILS_INTEGRATION.md](RAILS_INTEGRATION.md)

## Publishing Notes

- Publish on the project site, Dev.to, Hashnode, or a personal engineering blog.
- Keep the canonical code snippets identical to the repo README so external content does not drift.
- Every external post should link back to the repo and one runnable example.
