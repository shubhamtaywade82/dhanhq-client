# Technical Analysis Guide

This guide explains how to use the technical analysis modules bundled with this gem: fetching historical OHLC, computing indicators, and producing multi-timeframe summaries.

## Modules Overview

- `TA::TechnicalAnalysis`: Fetches intraday OHLC (1/5/15/25/60) from Dhan APIs with throttling/backoff, computes RSI/MACD/ADX/ATR, and returns a structured indicators hash.
- `TA::Indicators`: Adapters for `ruby-technical-analysis` and `technical-analysis` gems, including safe fallbacks.
- `TA::Candles`: Utilities for converting API series to candles and resampling (used for offline data only).
- `TA::Fetcher`: Handles API calls, 90-day windowing, throttling, and retries.
- `DhanHQ::Analysis::MultiTimeframeAnalyzer`: Consumes the indicator hash and outputs a consolidated bias summary across timeframes.

## Prerequisites

- Environment variables set: `DHAN_CLIENT_ID`, `DHAN_ACCESS_TOKEN`
- Optional indicator gems:
  - `gem install ruby-technical-analysis technical-analysis`

## Quick Start: Compute Indicators

```ruby
require "dhan_hq"
require "ta"

DhanHQ.configure_with_env

ta = TA::TechnicalAnalysis.new(throttle_seconds: 2.5, max_retries: 3)
indicators = ta.compute(
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  instrument: DhanHQ::Constants::InstrumentType::EQUITY,
  security_id: "1333",
  intervals: [1, 5, 15, 25, 60] # each fetched directly from API
)
```

Output structure:

```ruby
{
  meta: { exchange_segment: "...", instrument: "...", security_id: "...", from_date: "YYYY-MM-DD", to_date: "YYYY-MM-DD" },
  indicators: {
    m1:  { rsi: Float|nil, adx: Float|nil, atr: Float|nil, macd: { macd: Float|nil, signal: Float|nil, hist: Float|nil } },
    m5:  { ... },
    m15: { ... },
    m25: { ... },
    m60: { ... }
  }
}
```

Notes:
- `to_date` defaults to today-or-last-trading-day via `TA::MarketCalendar`.
- If `days_back` is not provided, the class auto-selects a sufficient lookback (trading days) per the selected intervals and indicator periods (max of [2×ADX, MACD slow, RSI+1, ATR+1]).
- Requests are throttled with jitter; rate-limit errors trigger exponential backoff.

## Offline Input (JSON OHLC)

```ruby
raw = JSON.parse(File.read("ohlc.json"))
indicators = TA::TechnicalAnalysis.new.compute_from_file(
  path: "ohlc.json", base_interval: 1, intervals: [1,5,15,25,60]
)
```

## Analyze Multi-Timeframe Bias

```ruby
require "DhanHQ"

analyzer = DhanHQ::Analysis::MultiTimeframeAnalyzer.new(data: indicators)
summary = analyzer.call
```

Example summary:

```ruby
{
  meta: { security_id: "1333", instrument: DhanHQ::Constants::InstrumentType::EQUITY, exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ },
  summary: {
    bias: :bullish,             # :bullish | :bearish | :neutral
    setup: :buy_on_dip,         # :buy_on_dip | :sell_on_rise | :range_trade
    confidence: 0.78,           # 0.0..1.0 weighted across timeframes
    rationale: {
      rsi: "Upward momentum across M5–M60",
      macd: "MACD bullish signals dominant",
      adx: "Strong higher timeframe trend",
      atr: "Volatility expansion"
    },
    trend_strength: {
      short_term: :weak_bullish,
      medium_term: :neutral_to_bullish,
      long_term: :strong_bullish
    }
  }
}
```

## CLI Script

A convenience script exists at `bin/ta_strategy.rb` to compute indicators and print JSON. Example:

```bash
./bin/ta_strategy.rb --segment NSE_EQ --instrument EQUITY --security-id 1333 \
  --from 2025-10-06 --to 2025-10-07 --debug
```

Options:
- `--print-creds` to verify env
- `--data-file` to compute from JSON instead of API
- `--interval` (with `--data-file`) to specify base file interval
- `--rsi`, `--atr`, `--adx`, `--macd` to tune periods

## Options Buying Advisor CLI

Use `bin/options_advisor.rb` to compute indicators, summarize multi-TF bias, and produce a single index options-buying recommendation (CE/PE). If you do not provide `--spot`, the script fetches spot via MarketFeed LTP automatically.

Examples:

```bash
# Auto-fetch spot via MarketFeed.ltp and chain via OptionChain model
./bin/options_advisor.rb --segment IDX_I --instrument INDEX --security-id 13 --symbol NIFTY

# Provide pre-fetched option chain from file (JSON array of strikes)
./bin/options_advisor.rb --segment IDX_I --instrument INDEX --security-id 13 --symbol NIFTY \
  --chain-file ./chain.json

# Override spot explicitly
./bin/options_advisor.rb --segment IDX_I --instrument INDEX --security-id 13 --symbol NIFTY --spot 24890

# Verbose debug logging (prints steps to STDERR; JSON output unchanged)
./bin/options_advisor.rb --segment IDX_I --instrument INDEX --security-id 13 --symbol NIFTY --debug
```

Behavior:
- Spot: when `--spot` is omitted, the script calls `DhanHQ::Models::MarketFeed.ltp({ SEG => [security_id] })` and reads `data[SEG][security_id]["last_price"]`.
- Option chain: when `--chain-file` is omitted, the advisor fetches via `DhanHQ::Models::OptionChain` (nearest expiry), transforming OC into an internal array of strikes with CE/PE legs.
- Debugging: with `--debug`, the script logs options, spot resolution, indicators meta, missing fields per timeframe, analyzer summary, and advisor output to STDERR.

## Best Practices & Tips

- Keep intervals minimal per run to reduce rate limits; increase `throttle_seconds` if needed.
- For higher intervals (e.g., 60m), ensure adequate `days_back` (auto-calculation is enabled by default).
- The analyzer is heuristic; adjust weights or thresholds as your strategy matures.
- See the advisor helpers under `lib/dhanhq/analysis/helpers/` to customize bias and moneyness rules.
