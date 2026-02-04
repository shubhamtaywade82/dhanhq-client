## [Unreleased]

---

## [2.3.0] - 2026-02-04

### Added
- **Alert Orders**: `DhanHQ::Resources::AlertOrders` (BaseResource) and `DhanHQ::Models::AlertOrder` with full CRUD. Endpoints: GET/POST `/alerts/orders`, GET/PUT/DELETE `/alerts/orders/{id}` (per API docs). Validation via `DhanHQ::Contracts::AlertOrderContract`.
- **IP Setup**: `DhanHQ::Resources::IPSetup` (resource-only). Methods: `current` (GET `/ip/getIP`), `set(ip:)` (POST `/ip/setIP`), `update(ip:)` (PUT `/ip/modifyIP`) per API docs.
- **Trader Control (Kill Switch)**: `DhanHQ::Resources::TraderControl` (resource-only). Methods: `status` (GET `/trader-control`), `enable` (POST action ENABLE), `disable` (POST action DISABLE). `DhanHQ::Resources::KillSwitch` and `DhanHQ::Models::KillSwitch` remain for backward compatibility.
- **docs/API_VERIFICATION.md**: Documents alignment with [dhanhq.co/docs/v2](https://dhanhq.co/docs/v2/) and [api.dhan.co/v2](https://api.dhan.co/v2/#/) for EDIS, Alert Orders, IP Setup.

### Changed
- **EDIS**: Resource-only, aligned with [dhanhq.co/docs/v2/edis](https://dhanhq.co/docs/v2/edis/). Use `DhanHQ::Resources::Edis`: `form(params)` (POST `/edis/form`; isin, qty, exchange, segment, bulk), `bulk_form(params)` (POST `/edis/bulkform`), `tpin` (GET `/edis/tpin`), `inquire(isin)` (GET `/edis/inquire/{isin}`).
- **BaseResource**: Fixed path building: `all`/`find`/`create`/`update`/`delete` now pass relative endpoints (`""`, `"/#{id}"`) so the base path is not doubled.

---

## [2.2.2] - 2026-01-31

### Contracts (date validation)

- **from_date / to_date**: `from_date` must be strictly before `to_date` and must be a valid trading date (no weekend). `to_date` may be any date after `from_date` (format YYYY-MM-DD). Applied in `HistoricalDataContract`, `TradeHistoryContract`, and `ExpiredOptionsDataContract`.
- **HistoricalDataContract**: Added trading-day check for `from_date` and `from_date < to_date`; inherits `BaseContract`.

### Specs & tooling

- **Specs**: Base model, expired options, trade, and historical data specs updated to use weekday dates and expect `from_date must be before to_date`; VCR cassette `trade_history.yml` updated for new date.
- **RuboCop**: RSpec/ExampleLength in expired options contract spec fixed via `next_weekday` helper.

---

## [2.2.1] - 2026-01-31

### Authentication

- **RenewToken API**: Added `DhanHQ::Auth.renew_token(access_token, client_id, base_url: nil)` to refresh web-generated access tokens (24h validity). Calls GET `/v2/RenewToken` with `access-token` and `dhanClientId` headers; returns response hash with indifferent access (e.g. `accessToken`, `expiryTime`). Use in `access_token_provider` or `on_token_expired` to refresh and store the new token. Only valid for tokens generated from Dhan Web (not API key flow).
- **Dhan auth scope**: Documented that the gem does **not** implement API key/secret consent or Partner consent flows; apps obtain tokens via Dhan Web, API key OAuth, or Partner flow and pass them to the gem. See [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md).

### Documentation

- **docs/AUTHENTICATION.md**: Added “How you get the token (Dhan’s responsibility)” (Individual: Web token, RenewToken, API key; Partner: consent flow) and “RenewToken (web-generated tokens only)” with `DhanHQ::Auth.renew_token` usage and example. “See also” updated for GUIDE, rails_integration, TESTING_GUIDE, CHANGELOG 2.2.0/2.2.1.
- **README.md**: Note under Dynamic access token for RenewToken via `DhanHQ::Auth.renew_token` and that API key/Partner flows are implemented in the app.
- **GUIDE.md**: “Dynamic access token” section extended with RenewToken (`DhanHQ::Auth.renew_token`) and note that API key/Partner flows are in the app.
- **docs/TESTING_GUIDE.md**: Optional config comment for RenewToken and pointer to AUTHENTICATION.md (API key/Partner in app).
- **docs/rails_integration.md**: “Dynamic access token” section extended with RenewToken (web-generated tokens) and link to AUTHENTICATION.md.
- **docs/websocket_integration.md**, **docs/live_order_updates.md**: Notes updated for dynamic token, RenewToken, and API key/Partner in app.
- **docs/standalone_ruby_websocket_integration.md**, **docs/rails_websocket_integration.md**: Configuration section updated with RenewToken and AUTHENTICATION.md link.

### CI / Release

- **Release workflow**: Aligned with ollama-client: tag-based release (`on: push: tags: v*`), validate tag vs gem version, use `GEM_HOST_API_KEY` for RubyGems push (no credentials file), single retry with OTP. Removed GitHub Release step.
- **RELEASING.md**, **docs/RELEASE_GUIDE.md**: Updated to describe tag-only publish and `GEM_HOST_API_KEY`; removed references to “Create GitHub Release” and “Run tests” in release job.

### Fixes

- **RuboCop**: Layout/EmptyLineAfterGuardClause — added blank line after guard clauses in Configuration, WS client, market depth client, orders connection. Style/NilLambda — `-> { nil }` → `-> {}` in configuration_spec. RSpec/InstanceVariable — replaced `@token_call_count` and `@hook_called`/`@hook_error` with `let(:token_call_count)`, `let(:token_provider)`, `let(:hook_state)` in client_spec auth-failure examples.
- **CI**: Gemfile.lock updated for path gem version (DhanHQ 2.2.1) so `bundle install` in frozen mode succeeds.

### Added

- **lib/DhanHQ/auth.rb**: New module with `Auth.renew_token` for Dhan RenewToken API.

---

## [2.2.0] - 2026-01-31

### Authentication & token handling

- **Dynamic access token resolution**: Token can be resolved at request time via `config.access_token_provider` (Proc/lambda). When set, the provider is called on each request; when not set, the gem falls back to `config.access_token`. No memoization — token is fetched per request for production-safe rotation.
- **Auto-expiry detection**: API error code **807** (token expired) now raises `DhanHQ::TokenExpiredError` so callers can handle expiry explicitly. Error codes 401, 807, 809, and 808 are treated as auth failures for retry logic.
- **Retry-on-401 with token re-fetch**: When the API returns 401 or token-expired (InvalidAuthenticationError, InvalidTokenError, TokenExpiredError, AuthenticationFailedError) and `config.access_token_provider` is set, the client retries the request **once** after the next token resolution (provider is called again). No separate “refresh” call — the provider is the source of the new token.
- **Optional `on_token_expired` hook**: `config.on_token_expired` (callable) is invoked when an auth failure triggers a retry, before the retry is performed. Use for logging or refreshing token in your store; the retry then uses the token from `access_token_provider`.
- **`DhanHQ::AuthenticationError`**: New error for local auth failures (missing token or provider returned nil/empty). API-level auth errors continue to use `InvalidAuthenticationError` / `InvalidTokenError` / `TokenExpiredError` as before.

### Configuration

- **New**: `config.access_token_provider` — callable that returns the access token string at request time.
- **New**: `config.on_token_expired` — optional callable invoked when 401/token-expired triggers a retry (only when `access_token_provider` is set).
- **New**: `config.resolved_access_token` — returns the token to use (from provider or static `access_token`); raises `AuthenticationError` if provider returns nil/empty.

### Errors

- **New**: `DhanHQ::AuthenticationError` — raised when token cannot be resolved (missing config or provider returned nil/empty).
- **New**: `DhanHQ::TokenExpiredError` — raised when API returns error code 807 (token expired). Mapped from `DHAN_ERROR_MAPPING["807"]`.

### Tests

- **WebMock specs for auth failures**: `spec/dhan_hq/client_spec.rb` — contexts for 401, 403, 807, retry-on-401 with provider, retry then raise when 401 persists, and `on_token_expired` hook.
- **Response helper**: Spec for 807 → TokenExpiredError in `spec/dhan_hq/helpers/response_helper_spec.rb`.

### Documentation

- **README.md**: New subsection “Dynamic access token (optional)” under Configuration.
- **GUIDE.md**: Short “Dynamic access token” note and link to docs/AUTHENTICATION.md.
- **docs/AUTHENTICATION.md**: New doc for static vs dynamic token, retry-on-401, and auth-related errors.
- **docs/TESTING_GUIDE.md**: Optional access_token_provider / on_token_expired in config examples.
- **docs/rails_integration.md**: “Dynamic access token (optional)” with Rails initializer example.
- **docs/websocket_integration.md**, **docs/live_order_updates.md**: Pointer to docs/AUTHENTICATION.md for dynamic token.

### Backward compatibility

- **Non-breaking**: Existing `config.access_token = "static-token"` continues to work. `access_token_provider` is optional. Safe to release as a **minor** version bump.

---

## [2.1.11] - 2025-01-27

This release includes comprehensive bug fixes, security improvements, and reliability enhancements. All changes are **backward compatible** - no breaking changes.

### 🔴 Critical Fixes

#### Thread Safety & Concurrency
- **Rate limiter race condition**: Fixed thread safety issue where cleanup threads modified shared state without synchronization. Added mutex protection and graceful shutdown mechanism.
- **WebSocket thread safety**: Fixed callback iteration race condition by creating frozen snapshots to prevent modification during event emission.

#### Error Handling & Validation
- **Client credential validation**: Moved validation to request time (in `build_headers`) rather than initialization, maintaining backward compatibility while ensuring credentials are validated before API calls.
- **WebSocket error handling**: Added proper cleanup and state reset on exceptions, improved logging with backtraces for better debugging.
- **Price field validation**: Added comprehensive validation for all float fields (price, trigger_price, bo_profit_value, bo_stop_loss_value, drv_strike_price) to reject NaN, Infinity, and values exceeding reasonable bounds (1,000,000,000).

### 🟠 High Priority Fixes

#### Memory Management
- **Order tracker memory leak**: Fixed unbounded memory growth in WebSocket order tracker by implementing automatic cleanup with configurable limits:
  - Maximum tracked orders: 10,000 (configurable via `DHAN_WS_MAX_TRACKED_ORDERS`)
  - Maximum order age: 7 days (configurable via `DHAN_WS_MAX_ORDER_AGE`)
  - Automatic cleanup thread runs hourly

#### Reliability & Error Handling
- **JSON parse error handling**: Improved error handling for invalid JSON responses. Empty strings return empty hash (backward compatible), but truly invalid JSON now raises `DataError` with detailed logging.
- **Timeout configuration**: Added configurable timeouts to prevent requests from hanging indefinitely:
  - Connection timeout: 10s (configurable via `DHAN_CONNECT_TIMEOUT`)
  - Read timeout: 30s (configurable via `DHAN_READ_TIMEOUT`)
  - Write timeout: 30s (configurable via `DHAN_WRITE_TIMEOUT`)
- **Retry logic**: Added automatic retry with exponential backoff for transient errors (RateLimitError, InternalServerError, NetworkError, timeouts). Default: 3 retries with exponential backoff (1s, 2s, 4s, capped at 30s).

### 🟡 Medium Priority Fixes

#### Code Quality & Reliability
- **Order modification validation**: Added warning logs for invalid order states (TRADED, CANCELLED, EXPIRED, CLOSED) but still attempts API call - API handles final validation (backward compatible).
- **Error mapping**: Added logging for unmapped error codes to aid investigation and debugging.
- **Rate limiter cleanup**: Added `shutdown()` method to gracefully stop cleanup threads and prevent resource leaks.
- **Order operation logging**: Added structured logging for order placement and modification operations to aid debugging.

### 🔵 Low Priority Fixes

#### Code Quality
- **Code deduplication**: Made `delete` delegate to `destroy`, removing duplicate code.
- **Type consistency**: Added `.to_s` conversion for `id` method to ensure consistent string return type.
- **Response format logging**: Added logging for unexpected response formats in collection parsing to help identify API changes.

### ✅ API Compliance

- **Header validation**: Validates required headers (`access_token`, `client_id` for DATA APIs) before making requests, providing clear error messages.
- **202 Accepted status**: Properly handles `202 Accepted` status code for async operations (e.g., position conversion).

### ➕ Added

#### Configuration Options
- **Timeout configuration** via environment variables:
  - `DHAN_CONNECT_TIMEOUT` - Connection timeout in seconds (default: 10)
  - `DHAN_READ_TIMEOUT` - Read timeout in seconds (default: 30)
  - `DHAN_WRITE_TIMEOUT` - Write timeout in seconds (default: 30)
- **WebSocket order tracker configuration** via environment variables:
  - `DHAN_WS_MAX_TRACKED_ORDERS` - Maximum orders to track (default: 10,000)
  - `DHAN_WS_MAX_ORDER_AGE` - Maximum order age in seconds (default: 604,800 = 7 days)

#### Test Coverage
- `spec/dhan_hq/contracts/place_order_contract_spec.rb` - Comprehensive price validation tests
- `spec/dhan_hq/helpers/response_helper_spec.rb` - JSON parsing and error handling tests
- `spec/dhan_hq/ws/orders/client_spec.rb` - Order tracker cleanup and thread safety tests
- Updated existing specs to cover new functionality and improvements

### 🔄 Changed

- **Error handling**: Improved error messages and logging throughout the codebase
- **Thread safety**: Enhanced thread safety in rate limiter and WebSocket clients
- **Memory management**: Order tracker now automatically cleans up old orders
- **JSON parsing**: Invalid JSON now raises `DataError` with logging (empty strings still return empty hash for backward compatibility)

### 🗑️ Removed

- `lib/DhanHQ/contracts/modify_order_contract_copy.rb` - Removed unused duplicate file

### 📝 Notes

- **Backward Compatibility**: All changes maintain 100% backward compatibility. No breaking changes.
- **API Compliance**: All fixes align with official API documentation at https://api.dhan.co/v2/#/
- **Performance**: Memory leak fixes and cleanup mechanisms improve long-running application stability
- **Reliability**: Retry logic and improved error handling increase resilience to transient failures

## [2.1.10] - 2025-11-11

### Fixed
- Expired Options Data routing: send `client-id` header for `/v2/charts/rollingoption` by adding `/v2/charts/` to data API prefixes.
- Correct `HTTP_PATH` for `ExpiredOptionsData` resource to `/v2/charts`.
- Prevent false validation failures by allowing up to 31-day ranges (to_date non-inclusive).

### Changed
- Align `ExpiredOptionsData` contract with broker docs:
  - `interval` accepted as String (e.g., "1", "5", "15", "25", "60").
  - `security_id` validated as Integer.
- Input normalization for `ExpiredOptionsData.fetch`:
  - Coerce convertible types (`interval`, `security_id`, `expiry_code`).
  - Uppercase enums and `strike`, normalize `required_data` to downcased unique list.
- Improved examples and YARD docs to reflect the above.

## [2.1.9] - 2025-01-31

### Added
- **Comprehensive YARD documentation**: Added complete YARD documentation across all model classes with detailed parameter specifications, return types, and examples:
  - `DhanHQ::Models::Edis` - EDIS form, bulk form, TPIN, and inquiry methods documented
  - `DhanHQ::Models::ExpiredOptionsData` - Expired options data fetching with strike analysis helpers
  - `DhanHQ::Models::ForeverOrder` - Forever Order (GTT) creation, modification, and cancellation
  - `DhanHQ::Models::Funds` - Account fund information retrieval
  - `DhanHQ::Models::HistoricalData` - Daily and intraday historical candle data fetching
  - `DhanHQ::Models::Holding` - Portfolio holdings retrieval
  - `DhanHQ::Models::Margin` - Margin calculation for orders
  - `DhanHQ::Models::MarketFeed` - LTP, OHLC, and quote data fetching
  - `DhanHQ::Models::OptionChain` - Option chain data and expiry list fetching
  - `DhanHQ::Models::Order` - Order placement, modification, cancellation, and slicing
  - `DhanHQ::Models::Position` - Position management and conversion
  - `DhanHQ::Models::SuperOrder` - Multi-leg super order management
  - `DhanHQ::Models::Trade` - Trade book, order trades, and historical trades
  - `DhanHQ::Models::Profile` - User profile and account information
  - `DhanHQ::Models::KillSwitch` - Kill switch activation and deactivation
- All documentation includes:
  - Complete parameter documentation with types, descriptions, and valid values
  - Comprehensive return type specifications with response structure details
  - Multiple practical examples for each method
  - Response field normalization (snake_case) documentation
  - Error handling documentation with `@raise` tags
  - Special notes and prerequisites where applicable

### Changed
- **Documentation standards**: All model documentation now follows YARD best practices with:
  - Properly indented `@option` tags for better readability
  - Consistent use of YARD hash syntax for parameter and return types
  - Detailed response structure documentation with field types and descriptions
  - Clarified that `dhan_client_id` must be explicitly provided (not auto-injected) where applicable

## [2.1.8] - 2025-10-30

### Fixed
- Correctly map `underlying_seg` for option chain APIs:
  - Index instruments use `IDX_I`.
  - Stocks map to `NSE_FNO` or `BSE_FNO` based on the instrument's exchange.
- Implemented via `underlying_segment_for_options` in `DhanHQ::Models::InstrumentHelpers` and applied to `expiry_list` and `option_chain`.

## [2.1.7] - 2025-01-28

### Added
- **Instrument instance methods**: Added convenience methods to Instrument model for accessing market feed, historical data, and option chain data
  - `instrument.ltp` - Fetches last traded price using `DhanHQ::Models::MarketFeed.ltp`
  - `instrument.ohlc` - Fetches OHLC data using `DhanHQ::Models::MarketFeed.ohlc`
  - `instrument.quote` - Fetches full quote depth using `DhanHQ::Models::MarketFeed.quote`
  - `instrument.daily(from_date:, to_date:, **options)` - Fetches daily historical data using `DhanHQ::Models::HistoricalData.daily`
  - `instrument.intraday(from_date:, to_date:, interval:, **options)` - Fetches intraday historical data using `DhanHQ::Models::HistoricalData.intraday`
  - `instrument.expiry_list` - Fetches expiry list using `DhanHQ::Models::OptionChain.fetch_expiry_list`
  - `instrument.option_chain(expiry:)` - Fetches option chain using `DhanHQ::Models::OptionChain.fetch`
  - All methods automatically use the instrument's `security_id`, `exchange_segment`, and `instrument` attributes
- **InstrumentHelpers module**: Created reusable module to provide these convenience methods

### Changed
- Align Super Order documentation across README, README1, and GUIDE with the latest API contract (place, modify, cancel, list).
- Normalise remaining documentation examples to snake_case, including order update WebSocket callbacks and kill switch response guidance.

## [2.1.5] - 2025-01-27

### ⚠️ BREAKING CHANGES
- **Changed require statement**: `require 'DhanHQ'` → `require 'dhan_hq'`
  - This affects all Ruby files that require the gem
  - Update all `require 'DhanHQ'` statements to `require 'dhan_hq'` in your codebase
  - The gem name remains `DhanHQ` in your Gemfile, only the require statement changes

### Added
- **OptionChain validation**: Added proper parameter validation for `OptionChain.fetch` and `OptionChain.fetch_expiry_list` methods
  - `OptionChain.fetch` requires `underlying_scrip`, `underlying_seg`, and `expiry` parameters
  - `OptionChain.fetch_expiry_list` requires only `underlying_scrip` and `underlying_seg` parameters
  - Validates exchange segments against `%w[IDX_I NSE_FNO BSE_FNO MCX_FO]`
  - Validates expiry format as `YYYY-MM-DD` and ensures it's a valid date

### Fixed
- **RuboCop compliance**: Fixed all RuboCop offenses (179 → 0 offenses)
- **Documentation**: Updated all documentation examples to use `require 'dhan_hq'`
- **Documentation**: Correct Super Order examples to use snake_case parameters for `DhanHQ::Models` helpers
- **Documentation**: Normalise Super Order path placeholders and response fields to snake_case for consistency
- **Documentation**: Clarified that model helpers auto-inject `dhan_client_id`, removing the need to add it manually in Ruby payloads
- **Code quality**: Added comprehensive validation tests for OptionChain methods

### Changed
- **File structure**: Renamed main library file from `lib/DhanHQ.rb` to `lib/dhan_hq.rb` for better Ruby conventions
- **Require paths**: Updated all internal require statements to use snake_case naming

## [2.1.0] - 2025-09-20

- Add REST coverage for EDIS (`/edis/form`, `/edis/bulkform`, `/edis/tpin`, `/edis/inquire/{isin}`) and the account kill-switch endpoint.
- Harden client-side validations: enforce `SliceOrderContract` via `Order#slice_order`, `MarginCalculatorContract` before `/v2/margincalculator`, and `PositionConversionContract` prior to `/v2/positions/convert`.
- Adjust rate limiting to match the latest broker quotas, including a dedicated quote bucket.
- Improve Forever Order routing (`/v2/forever/orders`) and expose the user profile helper.

## [2.0.3] - 2025-09-18

- Refresh GUIDE.md to align with current DhanHQ contracts, models, and data services.

## [2.0.2] - 2025-09-16

- Add `DhanHQ::WS::Client#connected?` to expose connection state.

## [0.1.0] - 2025-01-23

- Initial release
