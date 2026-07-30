---
title: DhanHQ Technical Analysis — Ruby SDK
description: Technical analysis helpers for the DhanHQ Ruby gem including indicator computations over historical data for algorithmic trading strategies.
---

# Technical Analysis

Technical analysis helpers for computing indicators over historical market data.

## Fetch Historical Data

```ruby
candles = DhanHQ::Models::Chart.daily(
  security_id: "13",
  exchange_segment: "IDX_I",
  instrument: "INDEX",
  from_date: "2026-06-01",
  to_date: "2026-07-29"
)
```

## Indicator Computation

The gem provides helpers for common technical indicators. See the [Technical Analysis guide](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/TECHNICAL_ANALYSIS.md) for full documentation.

## Available Examples

The repository includes example scripts for building trading bots:

- [Build a Trading Bot with Ruby](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/BUILD_A_TRADING_BOT_WITH_RUBY_AND_DHAN.md)
- [Data API Parameters Reference](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/DATA_API_PARAMETERS.md)
- [Dhan API Ruby Examples](https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/DHAN_API_RUBY_EXAMPLES.md)
