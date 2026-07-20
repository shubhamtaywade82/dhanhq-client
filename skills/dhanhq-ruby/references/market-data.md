# Market Data — Complete Reference (Ruby SDK)

Timestamps returned by the `HistoricalData` model are automatically normalized into Ruby `Time` objects.

## Historical Daily Data

Use `DhanHQ::Models::HistoricalData.daily(params)`:

```ruby
candles = DhanHQ::Models::HistoricalData.daily(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  from_date: "2024-01-01",
  to_date: "2024-12-31",
  expiry_code: 0, # Optional: 0 for current, 1 for next, 2 for far
  oi: false       # Optional: true to include open interest
)

first_candle = candles.first
puts "Date: #{first_candle[:timestamp]}, Close: ₹#{first_candle[:close]}"
```

Each candle in the returned array is a Hash containing:
- `:timestamp` (Ruby `Time` object)
- `:open` (Float)
- `:high` (Float)
- `:low` (Float)
- `:close` (Float)
- `:volume` (Integer)
- `:open_interest` (Float, only if `oi: true` was requested)

## Intraday Minute Data

Use `DhanHQ::Models::HistoricalData.intraday(params)`:

```ruby
candles = DhanHQ::Models::HistoricalData.intraday(
  security_id: "2885",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  interval: "15", # Supported: "1", "5", "15", "25", "60"
  from_date: "2024-09-11 09:30:00",
  to_date: "2024-09-15 13:00:00",
  oi: false
)
```

- Max 90 days of data can be polled in a single request.
- Returns a normalized array of candle hashes.

---

## Market Quote Snapshots

REST quote snapshots are accessed via the `DhanHQ::Models::MarketFeed` model.

### Ticker Data (LTP only)

```ruby
response = DhanHQ::Models::MarketFeed.ltp(
  "NSE_EQ" => [2885, 1333],
  "NSE_FNO" => [49081]
)

ltp = response[:data]["NSE_EQ"]["2885"][:last_price]
```

### OHLC Data

```ruby
response = DhanHQ::Models::MarketFeed.ohlc(
  "NSE_EQ" => [2885]
)

ohlc = response[:data]["NSE_EQ"]["2885"][:ohlc]
```

### Quote Data (Full Quote Depth & Analytics)

```ruby
response = DhanHQ::Models::MarketFeed.quote(
  "NSE_FNO" => [49081]
)

quote = response[:data]["NSE_FNO"]["49081"]
puts "LTP: #{quote[:last_price]}, OI: #{quote[:oi]}, Vol: #{quote[:volume]}"
```

---

## Expired Options Data

Use `DhanHQ::Models::ExpiredOptionsData.fetch(params)` (or direct resource access):

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

---

## Timestamp Conversion

If using raw API responses where timestamps are UNIX epochs, convert them to Ruby Time:

```ruby
time = Time.at(epoch_timestamp)
```
