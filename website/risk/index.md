---
title: DhanHQ Risk Management — Ruby SDK
description: Risk management patterns for the DhanHQ Ruby gem including position limits, daily loss thresholds, and safety rails for live trading.
---

# Risk Management

The gem includes safety rails for live trading:

- **Validation before transport** — every order is validated via dry-validation contracts before hitting the API
- **No blind retries** — order placement is never auto-retried
- **Correlation ID** — mandatory for idempotent order tracking
- **Token lifecycle** — automatic retry-on-401 with token refresh

See the [Troubleshooting guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/TROUBLESHOOTING.md) and [Best Way to Use Dhan API in Ruby](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/BEST_WAY_TO_USE_DHAN_API_IN_RUBY.md) for detailed patterns.
