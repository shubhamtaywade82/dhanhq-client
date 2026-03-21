# Build A Trading Bot With Ruby And Dhan

This document is a draft outline for a use-case-first article. It is aimed at developers who are not looking for an SDK in the abstract; they want a trading bot and need the SDK as the implementation path.

## Target Reader

A Ruby developer who wants to:

- pull historical market data
- evaluate a simple signal
- watch live prices
- place guarded orders through Dhan

## Outline

### 1. Framing

Open with the user problem:

`We want a Ruby trading bot that can fetch data, decide, and execute without rebuilding Dhan auth and WebSocket plumbing from scratch.`

### 2. Minimal setup

Use:

```ruby
require "dhan_hq"
DhanHQ.configure_with_env
```

Mention:

- `DHAN_CLIENT_ID`
- `DHAN_ACCESS_TOKEN`
- `LIVE_TRADING=true` only for intentional live order placement

### 3. Build the signal

Reference [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb):

- fetch NIFTY 5-minute bars
- compute a simple SMA signal
- print bullish/bearish state

### 4. Add live monitoring

Reference [examples/options_watchlist.rb](../examples/options_watchlist.rb):

- connect to the market feed
- subscribe to the underlying
- stream quotes into your strategy loop

### 5. Execute safely

Explain:

- order models
- correlation IDs
- audit logging
- live trading guard

Use a commented `order.save` example so the article does not encourage accidental live trades.

### 6. Extend into an app

Route advanced users to:

- [docs/RAILS_INTEGRATION.md](RAILS_INTEGRATION.md)
- [docs/WEBSOCKET_INTEGRATION.md](WEBSOCKET_INTEGRATION.md)
- [docs/AUTHENTICATION.md](AUTHENTICATION.md)

## Publishing Notes

- Publish this after the search-focused “How to use Dhan API with Ruby” guide.
- Link back to the README quickstart and all referenced example files.
- Keep the article outcome-driven. Do not turn it into a full API reference.
