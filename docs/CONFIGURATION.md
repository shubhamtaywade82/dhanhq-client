# Configuration Reference

This document covers all configuration options for the DhanHQ Ruby client.

## Quick Setup

```ruby
require 'dhan_hq'
DhanHQ.configure_with_env
```

`configure_with_env` reads `DHAN_CLIENT_ID` and `DHAN_ACCESS_TOKEN` from `ENV` and raises if either is missing.

## Required Environment Variables

| Variable             | Purpose                                           |
| -------------------- | ------------------------------------------------- |
| `DHAN_CLIENT_ID`     | Trading account client ID issued by Dhan          |
| `DHAN_ACCESS_TOKEN`  | API access token generated from the Dhan console  |

## Optional Environment Variables

Set these _before_ calling `configure_with_env` to override defaults:

| Variable                         | Default    | Description                                             |
| -------------------------------- | ---------- | ------------------------------------------------------- |
| `DHAN_LOG_LEVEL`                 | `INFO`     | Logger verbosity (`DEBUG`, `INFO`, `WARN`, `ERROR`)     |
| `DHAN_BASE_URL`                  | Dhan prod  | Point REST calls to a different API hostname            |
| `DHAN_WS_VERSION`                | latest     | Pin WebSocket connections to a specific API version     |
| `DHAN_WS_ORDER_URL`              | Dhan prod  | Override the order update WebSocket endpoint            |
| `DHAN_WS_USER_TYPE`              | `SELF`     | Switch between `SELF` and `PARTNER` streaming modes     |
| `DHAN_PARTNER_ID`                | —          | Required when `DHAN_WS_USER_TYPE=PARTNER`               |
| `DHAN_PARTNER_SECRET`            | —          | Required when `DHAN_WS_USER_TYPE=PARTNER`               |
| `DHAN_CONNECT_TIMEOUT`           | `10`       | Connection timeout in seconds                           |
| `DHAN_READ_TIMEOUT`              | `30`       | Read timeout in seconds                                 |
| `DHAN_WRITE_TIMEOUT`             | `30`       | Write timeout in seconds                                |
| `DHAN_WS_MAX_TRACKED_ORDERS`     | `10000`    | Maximum orders to track in WebSocket                    |
| `DHAN_WS_MAX_ORDER_AGE`          | `604800`   | Maximum order age in seconds before cleanup (7 days)    |

## `.env` File Setup

Create a `.env` file in your project root:

```dotenv
DHAN_CLIENT_ID=your_client_id
DHAN_ACCESS_TOKEN=your_access_token

# Optional overrides
DHAN_LOG_LEVEL=DEBUG
DHAN_CONNECT_TIMEOUT=15
DHAN_READ_TIMEOUT=60
```

The gem requires `dotenv/load`, so these variables are loaded automatically when you require `dhan_hq`.

## Block-Style Configuration

```ruby
DhanHQ.configure do |config|
  config.client_id    = ENV["DHAN_CLIENT_ID"]
  config.access_token = ENV["DHAN_ACCESS_TOKEN"]
end
```

## Logging

```ruby
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |level| Logger.const_get(level) }
```

Set `DHAN_LOG_LEVEL=DEBUG` for full HTTP request/response and WebSocket frame logging during development.

## Dynamic Access Token

For production or OAuth-style flows, resolve the token at **request time**:

```ruby
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"]
  config.access_token_provider = lambda do
    token = YourTokenStore.active_token  # e.g. from DB or OAuth
    raise "Token expired or missing" unless token
    token
  end
  # Optional: called when the API returns 401/token-expired
  config.on_token_expired = ->(error) { YourTokenStore.refresh! }
end
```

- **`access_token_provider`**: Callable (Proc/lambda) returning the token string. Called on every request (no memoization). When set, the gem uses it instead of `access_token`.
- **`on_token_expired`**: Optional callable invoked when a 401/token-expired triggers a **single retry** (only when `access_token_provider` is set).

For detailed authentication flows, see [AUTHENTICATION.md](AUTHENTICATION.md).

## Available Resources

| Resource                 | Model                                  | Actions                                             |
| ------------------------ | -------------------------------------- | --------------------------------------------------- |
| Orders                   | `DhanHQ::Models::Order`                | `find`, `all`, `where`, `place`, `update`, `cancel` |
| Trades                   | `DhanHQ::Models::Trade`                | `all`, `find_by_order_id`                           |
| Forever Orders           | `DhanHQ::Models::ForeverOrder`         | `create`, `find`, `modify`, `cancel`, `all`         |
| Holdings                 | `DhanHQ::Models::Holding`              | `all`                                               |
| Positions                | `DhanHQ::Models::Position`             | `all`, `find`, `exit!`                              |
| Funds & Margin           | `DhanHQ::Models::Fund`                 | `fund_limit`, `margin_calculator`                   |
| Ledger                   | `DhanHQ::Models::Ledger`               | `all`                                               |
| Market Feeds             | `DhanHQ::Models::MarketFeed`           | `ltp`, `ohlc`, `quote`                              |
| Historical Data (Charts) | `DhanHQ::Models::HistoricalData`       | `daily`, `intraday`                                 |
| Option Chain             | `DhanHQ::Models::OptionChain`          | `fetch`, `fetch_expiry_list`                        |
| Super Orders             | `DhanHQ::Models::SuperOrder`           | `create`, `modify`, `cancel`, `all`                 |
