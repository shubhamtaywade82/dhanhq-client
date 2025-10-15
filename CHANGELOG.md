## [Unreleased]

### Changed
- Align Super Order documentation across README, README1, and GUIDE with the latest API contract (place, modify, cancel, list).

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
