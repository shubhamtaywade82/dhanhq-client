# dhanhq-client Architecture

This document describes the architecture of the DhanHQ v2 API client gem: layers, dependencies, and design patterns in use.

## Guiding principles

- **Dependency rule**: High-level policy (models, domain) does not depend on low-level details (HTTP, JSON). Infrastructure (Client, BaseAPI) depends on configuration and helpers; models depend on resources (abstractions) and contracts.
- **Single responsibility**: Each layer has one reason to change. Models own domain behavior; resources own HTTP; contracts own validation rules.
- **Open/closed**: New endpoints are added by adding new Model + Resource + Contract pairs without modifying BaseAPI or BaseModel core.
- **Don’t force patterns**: Patterns (Strategy, Factory Method, Facade) emerged from refactoring; we avoid speculative abstraction.

---

## Layer overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Entry & configuration (lib/dhan_hq.rb, Configuration)          │
├─────────────────────────────────────────────────────────────────┤
│  Domain / facade layer (Models)                                 │
│  Order, Position, MarketFeed, OptionChain, ExpiredOptionsData…  │
│  → validate via Contracts, delegate HTTP to Resources           │
├─────────────────────────────────────────────────────────────────┤
│  REST / HTTP layer (Resources, BaseAPI, BaseResource)           │
│  → build path, format params, call Client                       │
├─────────────────────────────────────────────────────────────────┤
│  Transport layer (Client, RateLimiter, RequestHelper,           │
│  ResponseHelper)                                                │
│  → Faraday, headers, retries, error mapping                     │
├─────────────────────────────────────────────────────────────────┤
│  Validation (Contracts)                                         │
│  → Dry::Validation, shared macros in BaseContract               │
├─────────────────────────────────────────────────────────────────┤
│  WebSocket (WS::*) — separate subsystem                         │
├─────────────────────────────────────────────────────────────────┤
│  AI / Agent layer (Agent, Skills, Risk, MCP) — separate subsystem│
│  MCP server (JSON-RPC over stdio) → Agent::ToolRegistry          │
│  → primitive tools (Models) + skill tools (Skills::Registry)     │
│  → gated by Agent::Policy + Risk::Pipeline before any order      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Directory structure and roles

| Path | Role | Responsibility |
|------|------|----------------|
| `lib/dhan_hq.rb` | Entry point | Zeitwerk setup, eager load of core/helpers/errors, `DhanHQ.configure` |
| `core/` | Base abstractions | BaseAPI (HTTP verbs, path building, param formatting), BaseModel (attributes, resource, validation, CRUD helpers), BaseResource (CRUD on BaseAPI), AuthAPI, ErrorHandler |
| `helpers/` | Cross-cutting | APIHelper, AttributeHelper (keys, normalization), ValidationHelper (validate_params!, validate!), RequestHelper (headers, payload, build_from_response), ResponseHelper (parse_json, handle_response, error mapping) |
| `models/` | Domain / facade | Typed wrappers (Order, Position, Holding, etc.). Define `resource`, optional `validation_contract`, and domain methods. Validate then delegate to resource. |
| `models/global_stocks/`, `resources/global_stocks/` | US equities book | DhanHQ's Global Stocks API (`/v2/globalstocks/*`) — its own Order, Trade, Holding, Funds (USD), Margin, OrderEstimate and MarketStatus. Namespaced so a USD position is never mistaken for an INR one. Orders here have no exchange segment / product type / validity, quantity is a float (fractional shares), and `AMOUNT` adds notional orders. The India-specific `Risk::Pipeline` does not apply. |
| `resources/` | REST wrappers | One class per API surface (Orders, Positions, MarketFeed, OptionChain, …). Set `HTTP_PATH`, `API_TYPE`; implement get/post/put/delete via BaseAPI. |
| `contracts/` | Request/response validation | Dry::Validation contracts (PlaceOrderContract, ModifyOrderContract, OptionChainContract, etc.). BaseContract provides shared macros (e.g. lot_size, tick_size). |
| `auth/` | Token lifecycle | Token generator/renewal/manager for dynamic tokens. |
| `concerns/` | Shared behavior | Modules included across layers (e.g. `OrderAudit` for live trading guard + audit logging, included in all order resources). |
| `utils/` | Utilities | Cross-cutting utilities not tied to a single layer (e.g. `NetworkInspector` for IP/hostname/env lookup used by order audit logging). |
| `dry_run/`, `write_paths.rb` | Write-path collaborators | `WritePaths` classifies a request as mutating / order-placing; `DryRun::Simulator` answers mutating requests locally and `DryRun::Ledger` remembers simulated orders so the models' refetch resolves without a live call. Extracted from `Client`, which was accumulating HTTP, auth retry, transient retry, rate limiting, path taxonomy and simulation. |
| `ws/` | WebSocket | Connection, packets, decoder, market depth, orders client — isolated from REST. |
| `mcp/` | MCP server | `DhanHQ::MCP::Server` — hand-rolled JSON-RPC 2.0 stdio server. Exposes `tools/list`, `tools/call`, `resources/*`, `prompts/*` to any MCP client (Claude Desktop, Claude Code, etc.). Launched via `exe/dhanhq-mcp`. |
| `agent/` | AI tool registry | `Agent::ToolRegistry` — 12 domestic primitives (`dhan_profile`, `dhan_place_order`, …), 9 Global Stocks / basket tools (`dhan_global_*`, `dhan_multi_order`), plus one `dhan_skill_*` tool per registered `Skills::Registry` entry (32 total). `Agent::Policy` gates every call by scope + `LIVE_TRADING`/`DHANHQ_MCP_ENABLE_WRITES`. `Agent::OrderPreview` validates without submitting. |
| `skills/` | Composable strategies | `Skills::Base` DSL (`param`, `step`, `risk`, `scope`, `description`) + `Skills::Registry`. 11 builtin skills (`iron_condor`, `straddle`, `strangle`, `buy_atm_call`, `covered_call`, `protective_put`, `bull_put_spread`, `bear_call_spread`, `square_off_all`, `square_off_position`, `market_data_summarizer`) under `skills/builtin/`. |
| `risk/` | Pre-trade risk gate | `Risk::Pipeline.run!` — runs `TradingPermission`, `AsmGsm`, `ProductSupport`, `OrderType`, `Quantity`, `MarketHours`, `PositionLimits`, `Concentration`, `Options` (options-only), `MaxLoss` (daily) under `risk/checks/`. Wired into every order-placing resource via `Concerns::OrderAudit#run_risk_checks!` and into the `dhan_place_order` MCP tool. |
| `ai/` | LLM prompt helpers | `AI::PromptHelpers` — human-readable portfolio summaries and risk reports, consumed by the MCP server's `prompts/get`. |
| `strategy/`, `market_data/`, `option_analytics/`, `events/` | Analysis modules | Strategy base class, market-data snapshot/OHLC types, option analytics (Black-Scholes, max pain), and typed event objects (`Events::Base`, `Events::Bus`). Zeitwerk-autoloaded like the rest of `DhanHQ::*` — distinct from the separate opt-in `lib/dhanhq/analysis` and `lib/dhanhq/ta` modules (lowercase namespace, require explicitly; see [3.0.0] in CHANGELOG.md). |

---

## Dependency flow

- **Configuration** is global (`DhanHQ.configuration`). Client and helpers read it (access_token, client_id, base_url).
- **Models** depend on:
  - **Resources** (Factory Method: `resource` returns the right BaseAPI subclass)
  - **Contracts** (for validate_params!)
  - **Helpers** (via BaseModel: ValidationHelper, RequestHelper, ResponseHelper, AttributeHelper, APIHelper)
- **Resources** depend on:
  - **Client** (injected via BaseAPI: `DhanHQ::Client.new(api_type)`)
  - **Helpers** (BaseAPI includes APIHelper, AttributeHelper; Client uses RequestHelper, ResponseHelper)
- **Client** depends on Configuration, RateLimiter, and helpers. No dependency on Models or Resources.
- **Contracts** depend on Constants (and optional instrument_meta). No dependency on Models or HTTP.

So: **Models → Resources → Client**; **Contracts** are used by Models (and optionally Resources); **Helpers** are used by Client, BaseAPI, and BaseModel.

---

## Design patterns in use

| Pattern | Where | Purpose |
|--------|--------|--------|
| **Facade** | Models (e.g. `Order.place`, `MarketFeed.ltp`) | Single entry point for “place order” or “get LTP”; hide validation, normalization, and resource call. |
| **Factory Method** | BaseModel `resource` | Subclasses override `resource` to return the correct REST wrapper (e.g. Orders, OptionChain) without callers knowing the class. |
| **Strategy** | BaseAPI `param_formatter_for(full_path)` | Choose how to format params by path: pass-through (marketfeed), titleize (optionchain), default camelize. Encapsulated in lambdas. |
| **Template Method** | BaseModel `save` | `save` calls `new_record? ? create : update`; subclasses override `create`/`update` or collection methods. |
| **Adapter** | RequestHelper / ResponseHelper | Adapt external API (headers, JSON, status codes) to internal hashes and error classes. |
| **Singleton (per API type)** | RateLimiter.for(api_type) | One rate limiter per API type so all clients share limits. |

---

## Error handling

- **Validation failures**: Raised as `DhanHQ::ValidationError` with a message that includes contract errors (e.g. `"Invalid parameters: #{result.errors.to_h}"`). Used by ValidationHelper, ExpiredOptionsData, Trade, and any code that validates via contracts.
- **HTTP / API errors**: Mapped in ResponseHelper (e.g. 401 → InvalidAuthenticationError, 807 → TokenExpiredError) and raised as appropriate `DhanHQ::*` subclasses.
- **Client** retries on auth failures (once, with token refresh) and on transient/network errors (with backoff).

---

## Configuration

- Credentials and URLs live in `DhanHQ::Configuration` (access_token, client_id, base_url, sandbox, optional access_token_provider).
- `DhanHQ.configure { }`, `configure_with_env`, and `configure_from_token_endpoint` set configuration. Never hardcode credentials; use env vars or token endpoint.
- Write-path behaviour is also configuration: `dry_run`, `retry_non_idempotent_writes`, `auto_correlation_id` (see below).

---

## Write-path safety

The distinction that matters on this API is **mutating vs read-only**, not GET vs POST — the
option chain, market feed, historical charts and margin calculators are all read-only POSTs.
`Constants::MUTATING_PATH_PREFIXES` names the paths whose non-GET requests actually change
account state, and `ORDER_PLACEMENT_PATH_PREFIXES` narrows that to order creation.
`DhanHQ::WritePaths` wraps those lists as predicates so `Client` does not carry the taxonomy
itself. Two behaviours key off it:

- **Dry run** (`config.dry_run`): `DryRun::Simulator` logs mutating requests and answers them
  locally; reads still hit the API, so a strategy can be rehearsed against live prices.
  Because the models place-then-refetch, each simulated placement is recorded in
  `DryRun::Ledger` and reads for a `DRYRUN-…` id are replayed from it — otherwise the refetch
  would carry a fabricated id to the live API. Responses are shaped per endpoint family: a
  placement needs an `orderId` for the models to treat it as successful, and the basket
  endpoint needs a per-leg `orders` array.
- **Retry gating**: the API has no idempotency key, so a `POST /v2/orders` that times out may
  already have reached the exchange. Mutating writes are therefore **not** auto-retried by
  default (`config.retry_non_idempotent_writes`), while reads keep their exponential backoff.
  `config.auto_correlation_id` fills in a `correlationId` so a caller can reconcile a timed-out
  placement through `GET /v2/orders/external/{correlation-id}`.

---

## WebSocket (WS)

- Separate subsystem under `DhanHQ::WS`: own connection, packet types, decoder, market depth, orders client.
- Shares configuration (e.g. access token) but not the REST Client or Resources.
- `WS::Connection` owns the socket, the reconnect loop with backoff, and subscription replay:
  the server keeps no subscription state across connections, so `SubState`'s snapshot is
  re-sent on every new session. It reports lifecycle transitions to its owner through an
  `on_event` callable rather than knowing about callbacks itself.
- `WS::Client` bridges those transitions onto its public callback bus (`:open`, `:reconnect`,
  `:close`, `:error`, plus decoded `:tick`s) and maintains health counters — `last_message_at`,
  `reconnect_count`, `healthy?`, `health`. Frame arrival is tracked separately from socket
  state because a feed can stay connected while the server stops publishing.

---

## Adding a new API surface

1. **Contract** (optional): Add a Dry::Validation contract under `contracts/` if the endpoint has structured input.
2. **Resource**: Add a class under `resources/` inheriting BaseAPI (or BaseResource). Set `HTTP_PATH`, `API_TYPE`; implement methods that call `get`/`post`/`put`/`delete`.
3. **Model**: Add a class under `models/` inheriting BaseModel. Override `resource` to return the new resource; override `validation_contract` if needed; implement class/instance methods that call `validate_params!` then `resource.*`.

This keeps the dependency rule and keeps each layer focused on one concern.
