---
title: Dhan Historical Data API — Ruby SDK & Client
description: Fetch intraday and daily OHLC charts using the DhanHQ Ruby gem for technical analysis and backtesting.
---

# Historical Data

## Intraday Charts

```ruby
candles = DhanHQ::Models::Chart.intraday(
  security_id:      "1333",
  exchange_segment: "NSE_EQ",
  instrument:       "EQUITY",
  interval:         "5",
  from_date:        "2026-07-28",
  to_date:          "2026-07-29"
)
```

## Daily Charts

```ruby
daily = DhanHQ::Models::Chart.daily(
  security_id:      "13",
  exchange_segment: "IDX_I",
  instrument:       "INDEX",
  from_date:        "2026-06-01",
  to_date:          "2026-07-29"
)
```
