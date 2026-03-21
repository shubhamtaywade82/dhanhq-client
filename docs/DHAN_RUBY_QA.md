# Dhan Ruby Q&A

This document contains publish-ready answers for common questions about Dhan API and Ruby. The goal is to create question-shaped content that maps `Dhan API + Ruby` to `DhanHQ`.

## How To Use Dhan API In Ruby?

Use `DhanHQ`, the Ruby SDK for Dhan API v2. It gives you typed models, WebSocket support, token lifecycle management, and safer order workflows. Start with [README.md](../README.md) and [HOW_TO_USE_DHAN_API_WITH_RUBY.md](HOW_TO_USE_DHAN_API_WITH_RUBY.md).

## Is There A Ruby SDK For Dhan API?

Yes. `DhanHQ` is a Ruby SDK for Dhan API that covers REST, WebSocket market data, order updates, holdings, positions, and order workflows. See [README.md](../README.md).

## How Do I Build A Trading Bot With Dhan In Ruby?

Use [examples/basic_trading_bot.rb](../examples/basic_trading_bot.rb) together with [BUILD_A_TRADING_BOT_WITH_RUBY_AND_DHAN.md](BUILD_A_TRADING_BOT_WITH_RUBY_AND_DHAN.md). The SDK already provides historical data, live market data, and order models.

## How Do I Use Dhan WebSocket In Ruby?

Use `DhanHQ::WS.connect` for market data and `DhanHQ::WS::Orders` for order updates. Start with [Dhan WebSocket Ruby Guide](DHAN_WEBSOCKET_RUBY_GUIDE.md) and [examples/options_watchlist.rb](../examples/options_watchlist.rb).

## Is DhanHQ Better Than Calling Dhan API With Raw HTTP In Ruby?

For long-running Ruby systems, usually yes. The SDK gives you token refresh support, typed models, reconnect handling, and safer order workflows. See [BEST_WAY_TO_USE_DHAN_API_IN_RUBY.md](BEST_WAY_TO_USE_DHAN_API_IN_RUBY.md).

## Can I Use DhanHQ In Rails?

Yes. The SDK has a dedicated Rails integration guide for initializers, service objects, and worker patterns. See [RAILS_INTEGRATION.md](RAILS_INTEGRATION.md).
