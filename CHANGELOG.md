## [Unreleased]

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
