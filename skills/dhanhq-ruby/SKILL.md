# DhanHQ Ruby SDK Skill

Use this skill when an agent needs to write, review, or operate Ruby code using the `DhanHQ` gem.

## Safety rules

- Prefer read-only tools and SDK calls unless the user explicitly asks to trade.
- Resolve instruments before trading with `DhanHQ::Models::Instrument.search` and use the returned `security_id` plus `exchange_segment`.
- Preview every order with `DhanHQ::Agent::OrderPreview` before any live order placement.
- Never place, modify, or cancel orders unless both `DHANHQ_MCP_ENABLE_WRITES=true` and `LIVE_TRADING=true` are set and the user has clearly confirmed the action.
- Include a `correlation_id` for every agent-originated order.
- Do not ask for or print access tokens.

## Setup

```ruby
require "dhan_hq"
require "dhan_hq/agent"

DhanHQ.configure_with_env
```

Required environment variables:

- `DHAN_CLIENT_ID`
- `DHAN_ACCESS_TOKEN`

Optional agent variables:

- `DHANHQ_AGENT_SCOPES`, comma-separated scopes such as `portfolio:read,market:read,orders:read`
- `DHANHQ_MCP_ENABLE_WRITES=true` for agent write tools
- `LIVE_TRADING=true` for any live trading write

## Common calls

```ruby
DhanHQ::Models::Profile.fetch
DhanHQ::Models::Funds.fetch
DhanHQ::Models::Holding.all
DhanHQ::Models::Position.all
DhanHQ::Models::Order.all
DhanHQ::Models::Trade.today
DhanHQ::Models::Instrument.search("RELIANCE", segments: ["NSE_EQ"], limit: 5)
DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => ["2885"])
```

## Order preview

```ruby
preview = DhanHQ::Agent::OrderPreview.new(
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "MARKET",
  validity: "DAY",
  security_id: "2885",
  quantity: 1,
  correlation_id: "agent-20260702-001"
)

preview.to_h
```

## MCP server

The gem includes a stdio MCP executable:

```bash
dhanhq-mcp
```

Start with read-only scopes. Add write scopes only for explicitly confirmed trading sessions.

See the references directory for focused workflows.
