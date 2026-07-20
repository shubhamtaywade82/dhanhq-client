# Backtesting With Dhan Data (Ruby SDK)

## Daily Equity Backtest Skeleton

```ruby
# Fetch daily charts via HistoricalData model
candles = DhanHQ::Models::HistoricalData.daily(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  from_date: "2023-01-01",
  to_date: "2024-12-31"
)

# candles is a normalized array of hashes:
# [{ timestamp: Time, open: Float, high: Float, low: Float, close: Float, volume: Integer }]
```

Typical next steps:
- Create signals based on technical calculations.
- Shift positions to avoid look-ahead bias.
- Apply transaction costs.
- Compute CAGR, maximum drawdown, Sharpe ratio, and win rate.

## Minute-Level Backtest Skeleton

```ruby
candles = DhanHQ::Models::HistoricalData.intraday(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  from_date: "2024-09-11 09:30:00",
  to_date: "2024-09-15 13:00:00",
  interval: "5", # 5-minute interval
  oi: false
)
```

## Expired Options Backtest Skeleton

```ruby
response = DhanHQ::Models::ExpiredOptionsData.fetch(
  underlying_scrip: 13,
  exchange_segment: "NSE_FNO",
  expiry_flag: "MONTH",
  expiry_code: 1,
  strike: "ATM",
  option_type: "CALL",
  required_data: ["open", "high", "low", "close", "volume", "oi", "spot"],
  from_date: "2021-08-01",
  to_date: "2021-08-31",
  interval: "1"
)
```

## Cost Model Reminders

At minimum consider:
- Brokerage charges
- Securities Transaction Tax (STT)
- Exchange transaction charges
- GST (Service Tax)
- Stamp duty
- SEBI turnover charges
- Slippage
