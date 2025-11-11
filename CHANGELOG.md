## [Unreleased]

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
