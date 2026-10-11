# Running Tests

All manual/connectivity tests live in **one script**: `bin/test_all`.

## CLI (run as script)

```bash
bin/test_all
```

Runs every **read** endpoint (GETs and POSTs that only fetch data: profile, funds, orders, marketfeed, optionchain, charts, margin, etc.).

Options:

| Option | Description |
|--------|-------------|
| `--list` | Print endpoint list and exit |
| `--skip-unavailable` | Skip endpoints that often 404/timeout in production |
| `--all` | Include write endpoints. Refuses to run unless the order tier routes to the sandbox (`DHAN_MODE=sandbox`, or `DHAN_MODE=hybrid` without an `order_api=live` override) |
| `--ip current` | Fetch current IP and exit |
| `--ip secondary` | Test updating SECONDARY IP and exit |
| `--json` | Output results as JSON |
| `--verbose` | Print each result |

Requires `DHAN_CLIENT_ID` and `DHAN_ACCESS_TOKEN` (or token endpoint). In `DHAN_MODE=hybrid` also set `DHAN_SANDBOX_CLIENT_ID` and `DHAN_SANDBOX_ACCESS_TOKEN` (from cloud.dhanhq.co). Optional: `DHAN_TEST_SECURITY_ID`, `DHAN_TEST_ORDER_ID`, `DHAN_TEST_ISIN`, `DHAN_TEST_EXPIRY`, `DHAN_TEST_CORRELATION_ID`.

### Live data + sandbox execution in one run

```bash
DHAN_MODE=hybrid \
DHAN_CLIENT_ID=... DHAN_ACCESS_TOKEN=... \
DHAN_SANDBOX_CLIENT_ID=... DHAN_SANDBOX_ACCESS_TOKEN=... \
bin/test_all --all --verbose
```

Market data (quotes, option chain, charts, instruments) is read from production while every
write goes to the sandbox. The run prints the effective routing per tier:

```
Mode: hybrid | Read-only: false
Routing: data_api=live, quote_api=live, option_chain=live, order_api=sandbox, non_trading_api=sandbox
```

Result tags: `[OK]`, `[ERR]`, and `[N/A]` for endpoints the Dhan sandbox does not serve
(super orders, alerts, P&L exit, IP setup, ...). `[N/A]` is not counted as an error, and those
requests are never sent to production instead. A read-only run (no `--all`) creates nothing on
the account.

## Console (load in bin/console)

1. Start the console: `bin/console`
2. Load the test script: `load 'bin/test_all'`
3. Run:
   - **`run_all_tests`** — quick smoke (config, funds, market feed, orders, positions, holdings, profile, instrument)
   - **`run_comprehensive_tests`** — full suite (all read APIs, validation, errors, rate limit, WebSocket)
   - Or individual helpers: `check_config`, `test_funds`, `test_market_feed`, `test_orders`, `test_positions`, `test_holdings`, `test_profile`, `test_instrument(symbol)`

### WebSocket checks (`run_comprehensive_tests`)

- Market feed ticker / quote / full on NIFTY: at least one packet must decode to a positive LTP.
- Full Market Depth at 20 and 200 levels on RELIANCE: subscribe, decode, sanity-check the book
  (non-empty, at most N levels per side, positive prices and quantities, no crossed book), then
  unsubscribe (request code 24).
- Order updates: connection only. In `:hybrid`/`:sandbox` this stream reports the real account,
  so sandbox orders never appear on it.

No data during market hours (weekdays 09:15–15:30 IST) is a **failure**; outside them the test is
**skipped**, not passed. There is no holiday calendar: on an exchange holiday set
`DHAN_TEST_MARKET_OPEN=false` (or `true` to force the strict check).

## What gets tested

- **CLI `bin/test_all`**: Every read endpoint (profile, funds, ledger, orders, positions, holdings, trades, forever/super orders, killswitch, IP, EDIS, alerts, pnlExit, marketfeed LTP/OHLC/quote, optionchain, historical, expired options, margin, instruments). With `--all`: write endpoints (orders, positions, killswitch, pnlExit, alerts, forever/super orders).
- **`run_all_tests`** (console): Config, funds, market feed, orders, positions, holdings, profile, instrument find.
- **`run_comprehensive_tests`** (console): Full suite — config, profile, funds, holdings, positions, orders, trades, instruments, market feed, historical, option chain, super/forever orders, EDIS, kill switch, margin, ledger, validation contracts, error handling, rate limiting, WebSocket (ticker/quote/full, order updates, market depth). Order write operations are disabled by default.

## Test Output

The test suite provides:
- ✓ Passed tests
- ✗ Failed tests with error messages
- ⚠ Warnings for skipped tests or expected failures
- Summary with pass/fail counts

## Example Output

```
================================================================================
DhanHQ Client Gem - Comprehensive Test Suite
================================================================================

--------------------------------------------------------------------------------
  Setup & Configuration
--------------------------------------------------------------------------------
  Testing: Configuration check... ✓
    ✓ Client ID: 1000000003
    ✓ Access Token: Set
    ✓ WS User Type: SELF
    ✓ Base URL: https://api.dhan.co/v2

  Testing: Environment variables check... ✓
    DHAN_CLIENT_ID: Set
    DHAN_ACCESS_TOKEN: Set
    DHAN_LOG_LEVEL: INFO

...

================================================================================
Test Summary
================================================================================
  Passed:  45
  Failed:  2
  Skipped: 0
  Total:   47
```

## Notes

1. **WebSocket Tests**: These require active market connections. If the market is closed, you may see warnings about no data received.

2. **Order Operations**: Write operations (place, modify, cancel orders) are disabled by default. Uncomment the `test_order_operations` method in the script to enable them.

3. **Rate Limiting**: The rate limiting test makes multiple rapid requests. Be aware of API rate limits.

4. **Error Handling**: Some tests intentionally trigger errors to verify error handling works correctly.

## Troubleshooting

### Configuration Errors
If you see configuration errors, ensure:
- `DHAN_CLIENT_ID` environment variable is set
- `DHAN_ACCESS_TOKEN` environment variable is set
- Run `DhanHQ.configure_with_env` in console

### WebSocket Connection Errors
- Check if market is open
- Verify WebSocket URL configuration
- Check network connectivity

### API Errors
- Verify your API credentials are valid
- Check if your IP is whitelisted (required for order operations)
- Review API rate limits

## Running individual checks

In console after `load 'bin/test_all'`:

```ruby
test_funds
test_market_feed
test_orders
# etc.
```

For the full suite, call specific sections via the runner:

```ruby
runner = DhanHQ::ComprehensiveTest::TestRunner.new
runner.test_funds
runner.test_market_feed
# etc.
```
