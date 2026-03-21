# Best Way To Use Dhan API In Ruby

The best way to use Dhan API in Ruby is usually not raw HTTP. It is a Ruby SDK that already understands the shape of trading workflows: authentication, market data, streaming, and order execution.

That is the role of `DhanHQ`, the Ruby SDK for Dhan API v2.

## SDK Vs Raw HTTP

Raw HTTP is fine when you only need one endpoint once.

For ongoing Ruby applications, the SDK is usually the better fit:

- typed models instead of manual JSON mapping
- token lifecycle support instead of handwritten refresh logic
- WebSocket reconnect and backoff instead of custom event-loop recovery
- live-trading guardrails instead of fragile order scripts
- one Ruby interface for market data, holdings, positions, and orders

## When Raw HTTP Is Enough

- you are writing a one-off experiment
- you only need one endpoint
- you do not need streaming or long-running behavior

## When The Ruby SDK Is Better

- you are building a trading bot
- you are integrating Dhan into a Rails app
- you need Dhan WebSocket support in Ruby
- you want clean abstractions over raw trading endpoints

## Start Here

- [README.md](../README.md)
- [HOW_TO_USE_DHAN_API_WITH_RUBY.md](HOW_TO_USE_DHAN_API_WITH_RUBY.md)
- [BUILD_A_TRADING_BOT_WITH_RUBY_AND_DHAN.md](BUILD_A_TRADING_BOT_WITH_RUBY_AND_DHAN.md)
