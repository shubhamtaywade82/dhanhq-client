# Contract-First Architecture — Assessment & Conversion Roadmap

> **Status: IMPLEMENTED (P0–P5)** — this roadmap has been executed on the
> `contract-first` branch. Phase status: ✅ P0 vendored contracts + overlays ·
> ✅ P1 registry + bindings + conformance suite + derived sandbox matrix ·
> ✅ P2 schema-derived validation (default-on requests, opt-in responses) ·
> ✅ P3 generated metadata + endpoint catalogue + contract-declared casing ·
> ✅ P4 WS protocol manifest wired into runtime + fixture round-trip ·
> ✅ P5 drift CI + property harness + governance. Remaining future work is
> limited to what the plan deliberately deferred (generated param structs
> per operation; AsyncAPI lifecycle document).
>
> Companion to [REVIEW.md](REVIEW.md) (findings F1–F9, recommendations M1–M9) and
> [GAP_ANALYSIS.md](GAP_ANALYSIS.md) (endpoint matrices). This document answers two questions:
>
> 1. What is contract-first architecture, exactly?
> 2. What would it take to make `DhanHQ` (v4.1.0) a *complete* contract-first gem?

---

## 1. What Contract-First Means

**Contract-first** is the discipline of making a machine-readable API contract — an OpenAPI 3.x
document, JSON Schema, and (for messaging) AsyncAPI — the **single source of truth** for what the
wire protocol is. Everything else in the client is then either **generated from** that contract,
**validated against** it, or **continuously cross-checked** with it.

The contrast:

| | Code-first (how most SDKs are written) | Contract-first |
|---|---|---|
| Source of truth | A human reads prose docs and writes code | The machine-readable contract, committed to the repo |
| Endpoint paths | Hard-coded strings in resource classes | Read from the contract (or generated stubs) |
| Request validation | Hand-written rules that may silently drift | Schemas derived from the contract |
| Response handling | Ad-hoc parsing, no schema knowledge | Responses validated against declared schemas |
| Upstream API changes | Discovered by users as runtime 4xx/bugs | Caught mechanically by CI spec-diff before release |
| Docs | Written by hand, rot quickly | Generated from the contract |
| Dual environments (live vs sandbox) | Parity maintained by hand | Parity computed by diffing the two contracts |

### The maturity ladder

Contract-first is not binary. There are five levels, and a "complete" conversion means reaching L4:

- **L0 — Prose-driven.** Code written from reading HTML docs. The gem started here.
- **L1 — Contract as reference.** The vendor spec is vendored in-repo; hand-written code is
  *conformance-tested* against it (every path/method/param the code uses must exist in the spec,
  and every spec operation must be mapped). Drift becomes a red test, not a user bug report.
- **L2 — Contract-driven validation.** Request payloads and response fixtures are validated at
  runtime / in CI against schemas *derived from the contract*, not hand-transcribed.
- **L3 — Contract-generated surface.** Operation metadata, typed parameter structs, models, and
  YARD docs are generated from the contract. Humans write only orchestration and domain logic.
- **L4 — Full contract governance.** CI re-downloads the vendor spec on a schedule, diffs it
  against the vendored copy, opens issues on drift; property-based testing (e.g. Schemathesis)
  exercises the sandbox host; docs and changelogs are generated from contract diffs.

---

## 2. Where the Gem Stands Today (Honest Audit)

The gem sits **between L0 and L1** — but unusually close to L1, because it already contains
proto-contracts that are just not *derived from* the vendor contract.

### 2.1 What already exists (assets)

| Asset | Location | Contract-first value |
|---|---|---|
| Live OpenAPI 3.0.1 spec — 47 paths, 63 operations (all with `operationId`), 75 schemas | `research/live_openapi_v2.json` (captured from `api.dhan.co/v2/v3/api-docs`) | **The** live contract, ready to vendor |
| Sandbox OpenAPI 3.0.1 spec — 22 paths, 27 operations, 25 schemas | `research/sandbox_openapi.json` (captured from `sandbox.dhan.co/v2/v3/api-docs`) | The sandbox contract; its diff vs live *is* the capability matrix |
| Byte-accurate WS + full-depth protocol reference | `../research/dhanhq-market-feed.md` | The contract for everything OpenAPI cannot express (binary WebSocket) |
| 32 hand-written dry-validation contracts | `lib/DhanHQ/contracts/*` | A validation runtime already exists; only the *derivation* is missing |
| `SandboxCapabilities` matrix + `SandboxUnsupportedError` | `lib/DhanHQ/sandbox_capabilities.rb` | Correct behaviour, hand-derived — should be *computed* from the two specs |
| 1,302-example test suite incl. VCR cassettes | `spec/` | Fixtures are ready-made inputs for schema-conformance tests |
| Manual conformance matrix (47/47 live paths covered) | `GAP_ANALYSIS.md` | Essentially a one-off L1 audit in prose — should become executable |

### 2.2 Where the code is *not* contract-first

1. **Endpoints are opaque strings.** `Resources::Orders` hard-codes `HTTP_PATH = "/v2/orders"` and
   calls `post("/slicing")`, `get("/external/#{correlation_id}")`. Nothing links these to a spec
   `operationId`. The knowledge "this verb = that contract operation" lives only in the author's head.
2. **Validation rules are hand-transcribed.** The 32 dry contracts are good, but they were typed
   from prose docs. Every enum (`EXCHANGE_SEGMENTS`, `ORDER_TYPES`, …) is a second, independent copy
   of what the spec's `components.schemas` already declares — and we have already *measured* the
   consequences: the F1–F9 bug class was precisely hand-transcription drift, and the research notes
   document spec-vs-docs enum conflicts (`NSE_COMM` vs `NSE_CURRENCY`) that nothing cross-checks.
3. **Casing is URL-sniffed.** `BaseAPI#param_formatter_for` picks `camelize` / `titleize` /
   pass-through by testing `full_path.include?("/marketfeed")` etc. That is implicit per-operation
   knowledge a contract would declare explicitly (`requestBody` schema per operation).
4. **Responses are unvalidated.** `handle_response` parses JSON into `HashWithIndifferentAccess`;
   models absorb whatever arrives. Multi-margin's snake_case-vs-camelCase inconsistency was found
   by reading, not by a schema test.
5. **The binary WebSocket layer is entirely outside any machine-readable contract.** The 12 packet
   decoders in `ws/packets/*` hand-encode byte offsets. Bugs F1–F7 (wrong request codes, wrong
   endianness, wrong lengths, dropped index packet) were all *protocol drift* — exactly the class of
   defect a machine-readable packet manifest makes impossible.
6. **Error mapping is hand-maintained.** `core/error_handler.rb` knows DH-901…910/8xx by hand
   (DH-911 is still unmapped — M6), while the spec's error responses are machine-readable.
7. **Sandbox parity is hand-written.** `sandbox_capabilities.rb` is a frozen matrix typed from
   research. If DhanHQ adds an endpoint to the sandbox spec, nothing in the gem notices.

---

## 3. The Conversion Plan (P0 → P5)

Designed so each phase ships value independently and never breaks the public API.

### P0 — Vendor the contracts + overlay pattern *(foundation, ~1–2 days)*

- Commit both specs under `contracts/dhanhq/live.openapi.json` and
  `contracts/dhanhq/sandbox.openapi.json` (move out of `research/`, which is not shipped).
- **Do not edit the vendor JSON in place.** DhanHQ's own spec is known imperfect (missing
  `/profile`, `/RenewToken`, instrument list; docs-only vs spec-only endpoint skew; enum conflicts).
  Keep a small set of **JSON Patch overlays** (`contracts/overlays/*.jsonpatch`) applied at load
  time, each documented with the reason and an upstream link. This makes "trust but verify"
  auditable and lets clean re-downloads replace the base spec safely.
- Add `rake contract:refresh` (re-download both `v3/api-docs` URLs, apply `git diff` so drift is
  visible in the PR, never silently overwrite).

### P1 — Operation registry: the executable conformance test *(~3–5 days)*

- New `DhanHQ::Contract::Registry` (load-time, frozen, zero runtime cost): parses both specs into
  `operationId → { http_method, path, host_tier (:order_api/:data_api/:non_trading_api),
  request_schema_ref, response_schema_refs, security, sandbox_supported? }`.
- Add an explicit **binding** from each resource verb to an operationId — either a small
  `operation :create_orders, id: "placeOrder"` DSL per resource, or a YAML map. ~60 bindings for
  live + ~12 for Global Stocks.
- New spec `spec/dhan_hq/contract/bindings_conformance_spec.rb` (this *is* GAP_ANALYSIS.md made executable):
  - every resource HTTP call targets a registry operation (no naked strings);
  - every live-spec operation is bound (or explicitly `xfail`-listed with reason — that is where
    the M1 iceberg/twap decision lands);
  - sandbox matrix in `sandbox_capabilities.rb` **equals** the diff of the two specs — the
    hand-written matrix becomes generated output, cross-checked by test.
- Rate-limit classes and error-code tables attach to operations from the registry (fixes M6's
  DH-911 gap at the same time).

### P2 — Schema-derived validation *(~1–2 weeks)*

- **Requests:** keep dry-validation for *semantic* rules the spec cannot express (lot-size and
  tick-size multiples, `instrument_meta` cross-checks) — that is genuinely hand-knowledge. But
  *structural* validation (required fields, types, enums, string bounds) moves to schemas compiled
  from the spec, run through `json_schemer` in a `Faraday` request middleware or in `BaseAPI`.
  The 32 contracts shrink to business-rule-only; the enum copies in `constants.rb` stop being a
  second source of truth (they get a cross-check test against spec enums instead).
- **Responses:** validate recorded VCR cassettes and (opt-in, `config.validate_responses = true`)
  live responses against response schemas. This converts upstream drift (casing flips, new fields,
  type changes) into a loud, early error.
- Sandbox and live get this for free from their respective specs — including the currently
  undocumented fact that the sandbox host only exposes 27 of 63 operations.

### P3 — Generated surface *(~2–4 weeks, incremental per resource family)*

The key design decision: **generate metadata and types, not a generic client.** Running
`openapi-generator` would produce a non-idiomatic Ruby client and throw away the gem's ergonomics
(risk pipeline, audit hooks, bang-writes, multi-instance clients). Instead, a small in-repo
generator (~300 lines, run via `rake contract:generate`) emits from the registry:

- typed **param structs** per operation (keyword-only, `Data`-class style, with yardoc from spec
  descriptions);
- **response models** for the 34 existing models — generated attribute lists + types, keeping the
  hand-written behaviour modules;
- **YARD docs** per resource method (path, operationId, rate-limit class, sandbox availability);
- the **casing strategy** per operation, replacing `param_formatter_for`'s URL sniffing with a
  per-operation declaration.

Resources keep their names and call signatures; the generated layer sits underneath
(`Resources::Orders#create → Registry[:placeOrder] → struct → middleware-validated request`).
Migrate one resource family at a time (orders → global stocks → data → misc), suite green after each.

### P4 — Machine-readable WebSocket protocol contract *(~1 week, highest defect-prevention ROI)*

OpenAPI cannot describe the market feed, so "complete" contract-first needs a second contract type:

- Encode the packet layouts from `research/dhanhq-market-feed.md` as a **binary protocol manifest**
  (`contracts/dhanhq/ws_protocol.yml`): per packet code — name, header fields, row layout, field
  offsets/types/endianness (already fully documented: 8-byte LE header; Ticker 16 B, Index 32 B,
  Quote 50 B, Depth 112 B, Full 162 B, FMD 12-byte header + 16-byte rows, stacked frames split by
  `msg_length`).
- Make `ws/packets/*` decoders **data-driven**: they interpret the manifest (`unpack` templates
  generated from it) instead of hand-writing offsets. Request codes (14/15/17/19/21/23, unsub
  +1, disconnect 12) and their subscription semantics become manifest data too.
- Optional: describe the WS lifecycle (auth query params, heartbeat 10 s/40 s, 5-connection cap,
  5,000 instruments/connection) in **AsyncAPI 2.x** alongside the manifest.
- Every one of F1–F7 becomes structurally impossible: a single YAML edit changes the wire format
  everywhere, and manifest-vs-SDK cross-check tests pin the published protocol.

### P5 — Governance & CI: what makes it "complete" *(~2–4 days + ongoing)*

- Scheduled CI job: `rake contract:refresh` against both hosts → drift PR with the spec diff.
- Property-based testing (Schemathesis or hand-rolled) against the sandbox host, restricted to
  safe read-only operations (`fundlimit`, `margincalculator`, `ledger`, `charts/*`) — the sandbox
  runs a **real OMS/RMS**, so never fuzz order placement.
- Contract tests: every VCR cassette validated against the schemas of the operation that produced it.
- Generate `docs/ENDPOINTS.md` and the rate-limit/error appendix from the registry; GAP_ANALYSIS.md
  becomes a generated artifact.
- Changelog discipline: any vendored-spec diff must ship with a gem-level decision
  (support / wrap / xfail-with-reason) before release.

---

## 4. Effort Summary

| Phase | Deliverable | Estimate | Unlocks |
|---|---|---|---|
| P0 | Vendored specs + overlays + refresh rake | 1–2 days | Single source of truth exists |
| P1 | Operation registry + executable conformance suite | 3–5 days | **L1** — drift becomes red tests |
| P2 | Spec-derived request/response validation | 1–2 weeks | **L2** — enum/structural drift dies |
| P3 | Generated param structs, models, docs | 2–4 weeks | **L3** — precision without losing ergonomics |
| P4 | Binary WS manifest + data-driven decoders | ~1 week | Contract coverage beyond OpenAPI; kills the F1–F7 class |
| P5 | CI drift detection + property tests + generated docs | 2–4 days | **L4** — self-maintaining conformance |

- **Full conversion (L4): roughly 5–8 weeks of focused work.**
- **The 80/20 (P0 + P1 + P2): roughly 1.5–2.5 weeks** and already delivers most of the value:
  this is the slice that would have mechanically caught every F1–F9 finding and the
  spec-vs-docs enum conflicts, before release.

## 5. What Contract-First Will *Not* Cover

Deliberate scope boundary: the contract governs the **wire** — paths, payloads, schemas, hosts,
binary frames, error codes. It does not generate the gem's differentiating layers: the risk
pipeline (`risk/checks/*`), trading skills, the agent/MCP tool catalogues, dry-run simulator and
backtest engine, and `instrument_meta`-aware lot/tick logic. Those encode *decisions*, not *facts
about the API*, and stay hand-written by design. Contract-first makes the facts trustworthy so the
hand-written logic can assume a correct foundation.

## 6. Risks & Mitigations

| Risk | Reality check | Mitigation |
|---|---|---|
| Vendor spec is defective/incomplete | Confirmed: docs-only vs spec-only endpoints, enum conflicts, casing inconsistencies | Overlay pattern (P0); xfail-list with reasons; never blind-generate |
| Specs can change under us | Spring-generated `v3/api-docs` regenerated per deploy | Drift CI (P5) turns surprise into a reviewed PR |
| Generic codegen ruins ergonomics | openapi-generator output fights the gem's design | Metadata/struct generation only (P3); resources stay hand-shaped |
| WS/binary outside OpenAPI | True of every trading API | P4 protocol manifest + optional AsyncAPI |
| Sandbox fuzzing hits real RMS | Official FAQ: sandbox is *not* paper trading | Property tests restricted to read-only ops (P5) |
| Validation adds latency on hot paths | Feed consumers bypass REST anyway | Schemas compiled once at boot; response validation opt-in per config |

## 7. Recommended First PR

P0 + P1 in one PR (~1 week): vendored specs, overlays, `Contract::Registry`, `rake contract:refresh`,
the conformance spec, and `sandbox_capabilities.rb` re-expressed as generated matrix + test.
It ships zero behaviour change (suite stays 1,302+ green) yet converts the two most valuable
documents — GAP_ANALYSIS.md and the sandbox matrix — from prose that rots into executable truth.
