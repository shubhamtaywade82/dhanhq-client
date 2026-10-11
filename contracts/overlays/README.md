# Contract Overlays

The vendored DhanHQ OpenAPI documents in [`contracts/dhanhq/`](../dhanhq/) are
**unmodified downloads** from the vendor:

| Document | Source |
|---|---|
| `live.openapi.json` | `https://api.dhan.co/v2/v3/api-docs` (Spring-generated, 47 paths / 63 operations) |
| `sandbox.openapi.json` | `https://sandbox.dhan.co/v2/v3/api-docs` (22 paths / 27 operations) |

The vendor spec is **imperfect**: endpoints documented in the prose docs are
missing from the machine-generated spec, and the spec carries no rate-limit
metadata. Rather than editing the vendor JSON in place (which would make clean
re-downloads impossible), every curated decision lives in a **JSON Patch (RFC
6902) overlay** applied at load time by `DhanHQ::Contract::SpecLoader`. Each
overlay is reviewed like code, and `rake contract:refresh` can always replace
the base document without losing our decisions.

## 0001-docs-only-endpoints.jsonpatch *(applies to: live)*

Adds the endpoints that the prose documentation describes but the generated
spec omits. Each added operation is marked `x-dhan-docs-only: true` and carries
the source docs URL; schemas are transcribed from prose, not generated, so they
are minimal (structural only). Added operations:

| Operation | Endpoint | Prose source |
|---|---|---|
| `getProfile` | `GET /profile` | docs/v2 authentication |
| `renewToken` | `POST /RenewToken` | docs/v2 authentication (used by `Auth::TokenRenewal`) |
| `getinstrumentlist` | `GET /instrument/{exchangeSegment}` | docs/v2 instruments (CSV redirect) |
| `marketfeedLTP` | `POST /marketfeed/ltp` | docs/v2 market-quote |
| `marketfeedOHLC` | `POST /marketfeed/ohlc` | docs/v2 market-quote |
| `marketfeedQuote` | `POST /marketfeed/quote` | docs/v2 market-quote |
| `optionchain` | `POST /optionchain` | docs/v2 option-chain |
| `optionchainexpirylist` | `POST /optionchain/expirylist` | docs/v2 option-chain |

None of these exist on the sandbox host, which the sandbox matrix derives
automatically from the sandbox document.

## 0002-rate-limit-annotations.jsonpatch *(applies to: live)*

Attaches `x-dhan-rate-limit-class` to **every** operation (vendor + overlay):
`order_api`, `data_api`, `option_chain`, `non_trading_api` or
`global_stocks_api`. The class keys match `DhanHQ::RateLimiter::RATE_LIMITS`
and the conformance suite fails if a new vendor operation ships unclassed, so
rate-limit routing can never silently regress. The budgets themselves live in
`lib/DhanHQ/rate_limiter.rb` (see REVIEW.md finding F8 for the corrected daily
caps).

## 0003-sandbox-quirks.jsonpatch *(applies to: sandbox)*

Attaches `x-dhan-quirks` behaviour notes to sandbox operations where the host
behaves in a way the schema cannot express: no market orders, `exchangeOrderId`
"0", DH-905 on live-valid payloads, fixed fund limit of 500, and real (not
simulated) chart data. `DhanHQ::Contract::Operation#quirks` exposes these for
error messages and docs.

## 0004-sandbox-verified-additions.jsonpatch *(applies to: sandbox)*

Encodes **verified reality that contradicts the vendor document**:
`sandbox.dhan.co/v2` serves `GET /profile` (HTTP 200 with the profile payload)
even though the sandbox OpenAPI document omits it. Evidence: the gem's own
recorded VCR cassette
`spec/vcr_cassettes/DhanHQ_sandbox_connectivity/successfully_retrieves_the_user_profile.yml`
(recorded 2026-03-07). The added operation is marked `x-dhan-verified-vcr: true`.

This keeps the sandbox capability guard **fail-closed for everything without
evidence** while not blocking a proven-working endpoint. If the vendor later
adds `/profile` to the sandbox spec, this overlay becomes a harmless no-op add
(same pointer, same operationId — review the refresh diff and drop it then).

## 0005-enum-reconciliation.jsonpatch *(applies to: live)*

Replaces `OrderRequest.exchangeSegment`'s enum. The vendor spec lists 6
segments and omits `IDX_I`, `NSE_CURRENCY`, `BSE_CURRENCY` — contradicting the
published annexure table (dhanhq.co/docs/v2/annexure) and the gem's audited
`Constants::ExchangeSegment`. After this overlay, schema-derived validation
(`config.validate_requests`, default on) accepts exactly the documented
segments. Enforced bidirectionally by `spec/dhan_hq/contract/enum_parity_spec.rb`.

## 0006-type-reconciliation.jsonpatch *(applies to: live)*

Widens `OptionChartRequest.securityId` (`POST /charts/rollingoption`) from the
vendor spec's `int32` to `string | integer`. The prose docs (docs.dhanhq.co,
*Historical Rolling Options Data*) type it as a string, so with request
validation on by default the vendor type alone would refuse every documented
call; `Models::ExpiredOptionsData` sends an integer, which stays valid.

## Refreshing the vendored documents

```bash
rake contract:refresh   # re-download both api-docs, git diff shows the drift
rake contract:check     # CI mode: exit non-zero if a fresh download differs
```

If the diff introduces new paths/operations, the workflow is:

1. review the drift (new operations need binding or a declared `unbound_operations` reason in `lib/DhanHQ/contract/bindings.yml`, and a rate-limit class in overlay 0002),
2. adjust overlays if needed,
3. run `bundle exec rspec spec/dhan_hq/contract/` and merge.
