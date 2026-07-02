# DhanHQ API, MCP, and Agent Skills Gap Analysis

This document compares the current Ruby gem surface with the public DhanHQ documentation pages reviewed on 2026-07-02:

- <https://docs.dhanhq.co/api/v2/>
- <https://docs.dhanhq.co/mcp/>
- <https://docs.dhanhq.co/skills>
- <https://docs.dhanhq.co/docs-export.md/>

## Implemented in this gem

This branch adds the first implementation pass for the gaps called out below:

- `DhanHQ::Models::Instrument.search` and `DhanHQ::Models::SearchResult` for local security resolution from the instrument master.
- `DhanHQ::Agent::Policy` for read/write scopes and environment-backed write gates.
- `DhanHQ::Agent::ToolRegistry` with JSON-Schema-like metadata for read-only market/portfolio/order tools, order preview, and write tools.
- `DhanHQ::Agent::OrderPreview` for dry-run order validation and confirmation summaries.
- `DhanHQ::MCP::Server` plus `exe/dhanhq-mcp` for stdio MCP tool listing/calls.
- `skills/dhanhq-ruby/SKILL.md` and focused references for Ruby-specific agent usage.

## Current gem coverage

The gem already covers most of the REST and streaming API surface expected from the Dhan API v2 documentation:

| Area | Current gem surface | Notes |
| --- | --- | --- |
| Orders | `DhanHQ::Resources::Orders`, `DhanHQ::Models::Order` | Place, modify, cancel, lookup, slicing, and correlation lookup are present. |
| Super orders | `DhanHQ::Resources::SuperOrders`, `DhanHQ::Models::SuperOrder` | Entry/target/stop-loss order lifecycle is present. |
| Forever/GTT orders | `DhanHQ::Resources::ForeverOrders`, `DhanHQ::Models::ForeverOrder` | Create, modify, cancel, list, and lookup are present. |
| Conditional alerts | `DhanHQ::Resources::AlertOrders`, `DhanHQ::Models::AlertOrder` | Alert order lifecycle is present. |
| Portfolio | holdings, positions, funds, profile resources/models | Core portfolio read APIs are present. |
| Statements | `DhanHQ::Resources::Statements`, `DhanHQ::Models::LedgerEntry` | Ledger and historical trade statement access is present. |
| Market snapshots | `DhanHQ::Resources::MarketFeed`, `DhanHQ::Models::MarketFeed` | LTP, OHLC, and quote snapshots are present. |
| Historical data | `DhanHQ::Resources::HistoricalData`, `DhanHQ::Models::HistoricalData` | Daily and intraday charts are present. |
| Option chain | `DhanHQ::Resources::OptionChain`, `DhanHQ::Models::OptionChain` | Option chain and expiry list are present. |
| Expired options | `DhanHQ::Resources::ExpiredOptionsData`, `DhanHQ::Models::ExpiredOptionsData` | Rolling expired option data is present. |
| Margin | `DhanHQ::Resources::MarginCalculator`, `DhanHQ::Models::Margin` | Single and multi-scrip margin calculations are present. |
| EDIS | `DhanHQ::Resources::Edis`, `DhanHQ::Models::Edis` | T-PIN, form, bulk form, and inquiry workflows are present. |
| Trader control | `DhanHQ::Resources::KillSwitch`, `DhanHQ::Resources::PnlExit` | Kill switch and P&L exit are present. |
| Static IP setup | `DhanHQ::Resources::IpSetup` | Static IP get/set/modify is present. |
| WebSockets | `DhanHQ::WS`, market depth, orders stream clients | Live feed, market depth, and order update stream clients are present. |
| Auth lifecycle | token manager, token generator, token renewal, retry-on-401 | Static and dynamic token workflows are present. |

## Gaps against API v2 docs

### 1. Official search/security-resolution workflow

The MCP documentation exposes a search tool for resolving company names, tickers, or indices to Dhan security IDs. The Ruby gem now exposes `DhanHQ::Models::Instrument.search` and `DhanHQ::Models::SearchResult` as a stable local-search wrapper over the instrument master. A dedicated HTTP `Search` resource can still be added later if Dhan publishes a public REST search endpoint.

Recommended addition:

- Keep the local-search wrapper as the default path, and add `DhanHQ::Resources::Search` only if Dhan exposes an HTTP search endpoint.
- Provide one canonical call such as `DhanHQ::Models::Instrument.search("RELIANCE")` returning security ID, exchange segment, instrument type, lot size, expiry, strike, and display symbol.
- Make this the required pre-trade resolution path for MCP and skills tooling.

### 2. ScanX / scanner workflows

The public skills material lists ScanX as one of the skill categories. This gem currently includes technical-analysis helpers and options analysis, but no explicit ScanX/scanner resource, model, CLI, or documentation.

Recommended addition:

- Verify whether ScanX has public API endpoints.
- If public, add resources/contracts/models for scans and scanner result payloads.
- If not public, document ScanX as intentionally unsupported and route users toward local `TA` and analysis helpers.

### 3. Agent-native tool metadata

The API docs now position DhanHQ as agent-native with MCP and skills. The gem now publishes machine-readable tool metadata through `DhanHQ::Agent::ToolRegistry`. The next improvement is generating more of this metadata directly from existing dry-validation contracts.

Recommended addition:

- Add generated JSON Schemas for high-value operations: order preview/place/modify/cancel, holdings, positions, funds, LTP, quote, option chain, historical data, margin calculator, alerts, and security search.
- Derive schemas from existing contracts where possible so the Ruby SDK remains the source of truth.
- Include risk metadata per tool: read-only, order-write, destructive, requires market hours, requires explicit confirmation, and live-trading gated.

### 4. MCP server packaging

Dhan offers a first-party MCP server, and this Ruby gem now includes a lightweight Ruby-native stdio MCP executable, `dhanhq-mcp`, that wraps the SDK. The initial implementation intentionally keeps the transport small and safety-gated.

Recommended addition:

- Add an optional executable, for example `exe/dhanhq-mcp`, powered by a Ruby MCP server library or a small JSON-RPC stdio adapter.
- Keep it optional so the core SDK remains lightweight.
- Start with read-only tools, then add trading tools behind confirmation gates.
- Support stdio first for Claude Desktop/Cursor/Codex-style clients, then HTTP/SSE if there is clear demand.

### 5. Agent skills bundled with gem

Dhan publishes an external skill pack with 12 categories: orders, portfolio, market data, option chain, instruments, funds, live feed, error codes, common workflows, options analysis, backtesting, and ScanX. This gem now bundles `skills/dhanhq-ruby/SKILL.md` to teach agents the Ruby-specific API surface.

Recommended addition:

- Add `skills/dhanhq-ruby/SKILL.md` focused on this gem's Ruby API, not just the Python examples in Dhan docs.
- Add lazy-loaded references under `skills/dhanhq-ruby/references/` for orders, market data, WebSockets, options, Rails integration, and troubleshooting.
- Include runnable Ruby snippets that use `require "dhan_hq"`, `DhanHQ.configure_with_env`, models, resources, and safety flags.

### 6. Pre-trade safety preview

The gem blocks order placement unless `LIVE_TRADING=true` and emits audit logs, which is good for application safety. Agent workflows now have `DhanHQ::Agent::OrderPreview`, a dry-run/preview primitive that can be called before any live write tool.

Recommended addition:

- Add an order preview service that validates contract fields, resolves instrument metadata, validates lot size/tick size where possible, estimates margin, and returns a human-confirmable summary.
- Require MCP/skills trading tools to call preview before place/modify/cancel.
- Add an idempotency/correlation ID recommendation for every agent-originated write.

### 7. Permission scopes and consent model

Dhan MCP docs describe per-session permissions and explicit consent. The gem currently has environment-level live trading gating, and now also has `DhanHQ::Agent::Policy` as a reusable scope model for agent tools.

Recommended addition:

- Add a `DhanHQ::Agent::Policy` object with scopes such as `portfolio:read`, `market:read`, `orders:read`, `orders:write`, `orders:cancel`, `alerts:write`, and `risk:write`.
- Make MCP/skill wrappers require explicit grants and deny dangerous actions by default.
- Keep the existing `LIVE_TRADING=true` guard as the final runtime backstop.

### 8. Documentation alignment

The README advertises full REST coverage, but it does not mention the newer MCP and Agent Skills surfaces. There is also no roadmap explaining whether the gem will wrap Dhan's first-party MCP server, provide a Ruby-native server, or simply publish skill assets.

Recommended addition:

- Add a README section: "AI agents, MCP, and skills".
- Link this gap analysis from the README.
- Document a support matrix: first-party Dhan MCP server, Ruby-native MCP server, bundled Ruby skill pack, and existing SDK APIs.

## Recommended implementation roadmap

### Phase 1: Documentation and safety foundations

1. Add README links to MCP, Agent Skills, and this gap analysis.
2. Add `skills/dhanhq-ruby/SKILL.md` with safety rules and Ruby snippets.
3. Add an `Agent::Policy` skeleton and tool metadata registry without exposing a server yet.
4. Add order preview APIs and specs.

### Phase 2: Read-only MCP server

1. Add optional MCP dependencies or a tiny stdio JSON-RPC adapter.
2. Implement read-only tools: profile, funds, holdings, positions, orders list, trades list, LTP, quote, OHLC, historical data, option chain, expiry list, margin estimate, and search.
3. Add contract-driven JSON Schemas.
4. Add integration tests using stubbed SDK responses; do not call live APIs.

### Phase 3: Write-capable MCP tools

1. Add place/modify/cancel order tools only after preview and explicit confirmation.
2. Add alert order and kill switch tools with stricter scope requirements.
3. Add audit metadata for `agent_name`, `client_session_id`, `tool_name`, and confirmation transcript hash.
4. Add an environment variable such as `DHANHQ_MCP_ENABLE_WRITES=true` in addition to `LIVE_TRADING=true`.

### Phase 4: Skill pack maturity

1. Split skills into lazy references mirroring the public Dhan categories.
2. Add examples for Codex, Claude Code, Cursor, and VS Code-compatible clients.
3. Add a compatibility note for Dhan's first-party skill pack versus this gem's Ruby-specific skill pack.
4. Periodically diff public docs against the gem's resource list.

## Proposed MCP tool matrix

| Tool | SDK backing | Risk | Initial support |
| --- | --- | --- | --- |
| `dhan_profile` | `DhanHQ::Models::Profile.current` | Read-only | Phase 2 |
| `dhan_funds` | `DhanHQ::Models::Funds.current` | Read-only | Phase 2 |
| `dhan_holdings` | `DhanHQ::Models::Holding.all` | Read-only | Phase 2 |
| `dhan_positions` | `DhanHQ::Models::Position.all` | Read-only | Phase 2 |
| `dhan_orders` | `DhanHQ::Models::Order.all` | Read-only | Phase 2 |
| `dhan_trades` | `DhanHQ::Models::Trade.all` | Read-only | Phase 2 |
| `dhan_search_instruments` | new search wrapper | Read-only | Phase 2 |
| `dhan_ltp` | `DhanHQ::Models::MarketFeed.ltp` | Read-only | Phase 2 |
| `dhan_quote` | `DhanHQ::Models::MarketFeed.quote` | Read-only | Phase 2 |
| `dhan_option_chain` | `DhanHQ::Models::OptionChain.fetch` | Read-only | Phase 2 |
| `dhan_margin` | `DhanHQ::Models::Margin.calculate` | Read-only but trade-adjacent | Phase 2 |
| `dhan_order_preview` | new preview service | Read-only but trade-adjacent | Phase 1 |
| `dhan_place_order` | `DhanHQ::Models::Order.create` | Live write | Phase 3 |
| `dhan_modify_order` | `DhanHQ::Models::Order#save` / resource modify | Live write | Phase 3 |
| `dhan_cancel_order` | `DhanHQ::Models::Order#cancel` | Destructive write | Phase 3 |
| `dhan_alert_create` | `DhanHQ::Models::AlertOrder.create` | Live write | Phase 3 |
| `dhan_kill_switch` | `DhanHQ::Models::KillSwitch` | Account-level risk write | Phase 3 |

## Open questions

- Does Dhan expose public REST endpoints for search and ScanX, or are these MCP/skill-only capabilities today?
- Should this gem embed a Ruby-native MCP server, or only provide schemas/helpers used by an external server?
- Should trading tools require interactive confirmation from MCP clients, cryptographic confirmation tokens, or both?
- How should WebSocket subscriptions be represented in MCP, given long-lived streams are less natural for request/response tools?
- Should skill assets live in this gem, in a companion `dhanhq-ruby-skills` package, or both?
