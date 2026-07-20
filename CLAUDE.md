# dhanhq-client

Ruby gem — the canonical DhanHQ v2 API client for this workspace. All other trading repos depend on this gem.

## What it is

A pure-Ruby library wrapping the DhanHQ v2 REST + WebSocket API. Provides typed model classes, a rate limiter, request/response helpers, WebSocket streaming (`DhanHQ::WS`), and an AI-agent layer (MCP server, composable trading skills, pre-trade risk pipeline).

## Stack

- Ruby gem (no Rails)
- Zeitwerk autoloader (namespace: `DhanHQ`)
- RSpec + WebMock for tests
- RuboCop + rubocop-rspec for style

## Commands

```bash
bundle install
bundle exec rspec                          # run all specs
bundle exec rspec spec/path/to_spec.rb    # single file
bundle exec rubocop                        # lint
bundle exec rake                           # default: rspec + rubocop
```

## Architecture

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for layers, dependency flow, and design patterns.

```
lib/DhanHQ/
  core/          # BaseAPI, BaseModel, BaseResource
  helpers/       # APIHelper, AttributeHelper, ValidationHelper, RequestHelper, ResponseHelper
  models/        # Typed AR-like model classes (Order, Position, Holding, etc.)
  resources/     # REST resource wrappers
  contracts/     # Request/response contract validators
  concerns/      # Shared behavior modules (OrderAudit — runs the risk pipeline before every order)
  auth/          # Auth flow
  utils/         # Cross-cutting utilities (NetworkInspector)
  ws/            # WebSocket client and feed
  mcp/           # MCP server (JSON-RPC over stdio) — launched via exe/dhanhq-mcp
  agent/         # ToolRegistry (23 MCP tools), Policy (scope + live-trading gate), OrderPreview
  skills/        # Composable trading strategies — Skills::Base DSL + 11 builtin skills
  risk/          # Risk::Pipeline — pre-trade checks wired into every order path + dhan_place_order
  ai/            # AI::PromptHelpers — portfolio summaries / risk reports for MCP prompts
```

Entry point: `lib/dhan_hq.rb` — sets up Zeitwerk loader, eager-requires core files.

## Key classes

| Class | Purpose |
|---|---|
| `DhanHQ::BaseAPI` | HTTP base — all API calls go through here |
| `DhanHQ::BaseModel` | Typed attribute mapping for API responses |
| `DhanHQ::RateLimiter` | Enforces DhanHQ rate limits |
| `DhanHQ::WS` | WebSocket feed client |
| `DhanHQ::Configuration` | Client ID, access token, env setup |
| `DhanHQ::Utils::NetworkInspector` | Public IP, hostname, env for order audit logging |
| `DhanHQ::MCP::Server` | JSON-RPC 2.0 stdio server exposing tools/resources/prompts to MCP clients |
| `DhanHQ::Agent::ToolRegistry` | 12 primitive tools + 11 `dhan_skill_*` tools (23 total), each gated by `Agent::Policy` |
| `DhanHQ::Skills::Registry` | Composable trading strategies (`iron_condor`, `straddle`, `square_off_all`, …) |
| `DhanHQ::Risk::Pipeline` | Pre-trade risk checks — wired into every order-placing resource and `dhan_place_order` |

## Configuration

```ruby
DhanHQ.configure do |c|
  c.client_id    = ENV["DHAN_CLIENT_ID"]
  c.access_token = ENV["DHAN_ACCESS_TOKEN"]
end
```

Never hardcode credentials. Always use env vars.

## Critical rules

- **This gem is Indian markets only** (NSE/BSE). No Delta Exchange code ever enters here.
- Method signatures are the API contract depended on by `algo_trading_api`, `algo_scalper_api`, `vyapari`, etc. Never rename or remove public methods without checking dependents.
- DhanHQ order IDs are **not sequential** — never sort by them or use them as primary ordering.
- All specs use WebMock — never hit the real API in tests.
- `spec/spec_helper.rb` loads SimpleCov when `COVERAGE=true`.
- **`ENV["LIVE_TRADING"]="true"` required** to place orders. Tests that call `Resources::Orders#create` or `#slicing` must set this in a `before` block.
