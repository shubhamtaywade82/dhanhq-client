# Running Comprehensive Tests

This guide explains how to run the comprehensive test suite for the DhanHQ client gem.

## Quick Start

1. **Start the console:**
   ```bash
   bin/console
   ```

2. **Load the comprehensive test suite:**
   ```ruby
   load 'bin/comprehensive_test.rb'
   ```

3. **Run all tests:**
   ```ruby
   run_comprehensive_tests
   ```

## What Gets Tested

The comprehensive test suite covers:

### 1. Setup & Configuration
- Configuration check
- Environment variables validation

### 2. Model Testing (Read Operations)
- **Profile**: Fetch user profile
- **Funds**: Get account funds and margins
- **Holdings**: Get all holdings
- **Positions**: Get all positions
- **Orders**: Get all orders, find by ID
- **Trades**: Get today's trades and trade history
- **Instruments**: Find instruments, use helper methods
- **Market Feed**: LTP, OHLC, Quote data
- **Historical Data**: Daily and intraday data
- **Option Chain**: Expiry list and option chain
- **Super Orders**: Get all super orders
- **Forever Orders**: Get all forever orders (GTT)
- **EDIS**: TPIN, form, bulk form, inquire (resource-only; see dhanhq.co/docs/v2/edis)
- **Margin Calculator**: Calculate margin requirements
- **Ledger Entries**: Get ledger entries

### 3. Validation Contracts
- Place Order Contract (valid and invalid cases)
- Historical Data Contract (valid and invalid cases)
- NaN and Infinity validation
- Date range validation

### 4. Error Handling
- Network error handling with retry logic

### 5. Rate Limiting
- Rate limiter functionality

### 6. WebSocket Testing
- Market Feed WebSocket (Ticker, OHLC, Quote)
- Order Update WebSocket
- Market Depth WebSocket

### 7. Order Operations (Write)
- **Disabled by default** - Uncomment in the script to test order placement/modification

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
    CLIENT_ID: Set
    ACCESS_TOKEN: Set
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
- `CLIENT_ID` environment variable is set
- `ACCESS_TOKEN` environment variable is set
- Run `DhanHQ.configure_with_env` in console

### WebSocket Connection Errors
- Check if market is open
- Verify WebSocket URL configuration
- Check network connectivity

### API Errors
- Verify your API credentials are valid
- Check if your IP is whitelisted (required for order operations)
- Review API rate limits

## Running Individual Tests

You can also run individual test sections by modifying the `run_all` method or calling specific test methods directly:

```ruby
runner = DhanHQ::ComprehensiveTest::TestRunner.new
runner.test_funds
runner.test_market_feed
# etc.
```

## Using Test Helpers

The gem also includes quick test helpers in `bin/test_helpers.rb`:

```ruby
load 'bin/test_helpers.rb'
run_all_tests  # Quick tests
test_funds
test_market_feed
# etc.
```
