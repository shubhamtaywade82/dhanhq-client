# Data API Required Parameters

This document lists all required parameters for data APIs from LTP (Last Traded Price) to Option Chain.

## 1. Market Feed APIs

### 1.1 LTP (Last Traded Price)
**Method:** `DhanHQ::Models::MarketFeed.ltp`

**Required Parameters:**
- `params` [Hash{String => Array<Integer>}] - Payload mapping exchange segments to arrays of security IDs
  - Keys: Exchange segment strings (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ", "BSE_FNO", "IDX_I", etc.)
  - Values: Arrays of security IDs (integers)

**Example:**
```ruby
payload = {
  "NSE_EQ" => [11536, 3456],
  "NSE_FNO" => [49081, 49082]
}
response = DhanHQ::Models::MarketFeed.ltp(payload)
```

**Notes:**
- Up to 1000 instruments per request
- Rate limit: 1 request per second

---

### 1.2 OHLC (Open, High, Low, Close)
**Method:** `DhanHQ::Models::MarketFeed.ohlc`

**Required Parameters:**
- `params` [Hash{String => Array<Integer>}] - Payload mapping exchange segments to arrays of security IDs
  - Keys: Exchange segment strings (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ", "BSE_FNO", "IDX_I", etc.)
  - Values: Arrays of security IDs (integers)

**Example:**
```ruby
payload = {
  "NSE_EQ" => [11536]
}
response = DhanHQ::Models::MarketFeed.ohlc(payload)
```

**Notes:**
- Up to 1000 instruments per request
- Rate limit: 1 request per second

---

### 1.3 Quote (Full Market Depth)
**Method:** `DhanHQ::Models::MarketFeed.quote`

**Required Parameters:**
- `params` [Hash{String => Array<Integer>}] - Payload mapping exchange segments to arrays of security IDs
  - Keys: Exchange segment strings (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ", "BSE_FNO", "IDX_I", etc.)
  - Values: Arrays of security IDs (integers)

**Example:**
```ruby
payload = {
  "NSE_FNO" => [49081]
}
response = DhanHQ::Models::MarketFeed.quote(payload)
```

**Notes:**
- Up to 1000 instruments per request
- Rate limit: 1 request per second (uses separate quote API)

---

## 2. Historical Data APIs

### 2.1 Daily Historical Data
**Method:** `DhanHQ::Models::HistoricalData.daily`

**Required Parameters:**
- `security_id` [String] - Exchange standard ID for each scrip
- `exchange_segment` [String] - Exchange and segment identifier
  - Valid values: See `DhanHQ::Constants::EXCHANGE_SEGMENTS` (e.g., "NSE_EQ", "NSE_FNO", "BSE_EQ", "IDX_I", etc.)
- `instrument` [String] - Instrument type of the scrip
  - Valid values: See `DhanHQ::Constants::INSTRUMENTS` (e.g., "EQUITY", "FUTIDX", "FUTSTK", "OPTIDX", "OPTSTK", "INDEX", etc.)
- `from_date` [String] - Start date in YYYY-MM-DD format
- `to_date` [String] - End date (non-inclusive) in YYYY-MM-DD format

**Optional Parameters:**
- `expiry_code` [Integer] - Expiry of instruments for derivatives (0, 1, or 2)
- `oi` [Boolean] - Include Open Interest data for Futures & Options (default: false)

**Example:**
```ruby
data = DhanHQ::Models::HistoricalData.daily(
  security_id: "1333",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  from_date: "2022-01-08",
  to_date: "2022-02-08"
)
```

---

### 2.2 Intraday Historical Data
**Method:** `DhanHQ::Models::HistoricalData.intraday`

**Required Parameters:**
- `security_id` [String] - Exchange standard ID for each scrip
- `exchange_segment` [String] - Exchange and segment identifier
  - Valid values: See `DhanHQ::Constants::EXCHANGE_SEGMENTS`
- `instrument` [String] - Instrument type of the scrip
  - Valid values: See `DhanHQ::Constants::INSTRUMENTS`
- `interval` [String] - Minute intervals for the timeframe
  - Valid values: "1", "5", "15", "25", "60"
- `from_date` [String] - Start date
  - Format: YYYY-MM-DD or YYYY-MM-DD HH:MM:SS (e.g., "2024-09-11" or "2024-09-11 09:30:00")
- `to_date` [String] - End date
  - Format: YYYY-MM-DD or YYYY-MM-DD HH:MM:SS (e.g., "2024-09-15" or "2024-09-15 13:00:00")

**Optional Parameters:**
- `expiry_code` [Integer] - Expiry of instruments for derivatives (0, 1, or 2)
- `oi` [Boolean] - Include Open Interest data for Futures & Options (default: false)

**Example:**
```ruby
data = DhanHQ::Models::HistoricalData.intraday(
  security_id: "1333",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  interval: "15",
  from_date: "2024-09-11",
  to_date: "2024-09-15"
)
```

**Notes:**
- Maximum 90 days of data can be fetched in a single request
- Data available for the last 5 years

---

## 3. Option Chain APIs

### 3.1 Fetch Option Chain
**Method:** `DhanHQ::Models::OptionChain.fetch`

**Required Parameters:**
- `underlying_scrip` [Integer] - Security ID of the underlying instrument
- `underlying_seg` [String] - Exchange and segment of underlying
  - Valid values: "IDX_I" (Index), "NSE_FNO" (NSE F&O), "BSE_FNO" (BSE F&O), "MCX_FO" (MCX)
- `expiry` [String] - Expiry date in YYYY-MM-DD format

**Example:**
```ruby
chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: 13,
  underlying_seg: "IDX_I",
  expiry: "2024-10-31"
)
```

**Notes:**
- Rate limit: 1 request per 3 seconds
- Automatically filters out strikes where both CE and PE have zero `last_price`

---

### 3.2 Fetch Expiry List
**Method:** `DhanHQ::Models::OptionChain.fetch_expiry_list`

**Required Parameters:**
- `underlying_scrip` [Integer] - Security ID of the underlying instrument
- `underlying_seg` [String] - Exchange and segment of underlying
  - Valid values: "IDX_I" (Index), "NSE_FNO" (NSE F&O), "BSE_FNO" (BSE F&O), "MCX_FO" (MCX)

**Example:**
```ruby
expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
  underlying_scrip: 13,
  underlying_seg: "IDX_I"
)
```

**Notes:**
- Returns array of expiry dates in "YYYY-MM-DD" format
- Use this to get valid expiry dates before calling `fetch`

---

## 4. Expired Options Data API

**Method:** `DhanHQ::Models::ExpiredOptionsData.fetch`

**Required Parameters:**
- `exchange_segment` [String] - Exchange and segment identifier
  - Valid values: "NSE_FNO", "BSE_FNO", "NSE_EQ", "BSE_EQ"
- `interval` [String] - Minute intervals for the timeframe
  - Valid values: "1", "5", "15", "25", "60"
- `security_id` [Integer] - Underlying exchange standard ID for each scrip
- `instrument` [String] - Instrument type of the scrip
  - Valid values: "OPTIDX" (Index Options), "OPTSTK" (Stock Options)
- `expiry_flag` [String] - Expiry interval of the instrument
  - Valid values: "WEEK", "MONTH"
- `expiry_code` [Integer] - Expiry code for the instrument
- `strike` [String] - Strike price specification
  - Format: "ATM" for At The Money, "ATM+X" or "ATM-X" for offset strikes
  - For Index Options (near expiry): Up to ATM+10 / ATM-10
  - For all other contracts: Up to ATM+3 / ATM-3
- `drv_option_type` [String] - Option type
  - Valid values: "CALL", "PUT"
- `required_data` [Array<String>] - Array of required data fields
  - Valid values: "open", "high", "low", "close", "iv", "volume", "strike", "oi", "spot"
- `from_date` [String] - Start date in YYYY-MM-DD format
  - Cannot be more than 5 years ago
- `to_date` [String] - End date (non-inclusive) in YYYY-MM-DD format
  - Date range cannot exceed 31 days from from_date

**Example:**
```ruby
data = DhanHQ::Models::ExpiredOptionsData.fetch(
  exchange_segment: "NSE_FNO",
  interval: "1",
  security_id: 13,
  instrument: "OPTIDX",
  expiry_flag: "MONTH",
  expiry_code: 1,
  strike: "ATM",
  drv_option_type: "CALL",
  required_data: ["open", "high", "low", "close", "volume", "iv", "oi", "spot"],
  from_date: "2021-08-01",
  to_date: "2021-09-01"
)
```

**Notes:**
- Up to 31 days of data can be fetched in a single request
- Historical data available for up to the last 5 years
- Data is organized by strike price relative to spot

---

## Summary Table

| API                     | Required Parameters                                                                                                                                             | Optional Parameters | Rate Limit  |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- | ----------- |
| **LTP**                 | `params` (Hash: segment => [security_ids])                                                                                                                      | None                | 1 req/sec   |
| **OHLC**                | `params` (Hash: segment => [security_ids])                                                                                                                      | None                | 1 req/sec   |
| **Quote**               | `params` (Hash: segment => [security_ids])                                                                                                                      | None                | 1 req/sec   |
| **Daily Historical**    | `security_id`, `exchange_segment`, `instrument`, `from_date`, `to_date`                                                                                         | `expiry_code`, `oi` | Standard    |
| **Intraday Historical** | `security_id`, `exchange_segment`, `instrument`, `interval`, `from_date`, `to_date`                                                                             | `expiry_code`, `oi` | Standard    |
| **Option Chain**        | `underlying_scrip`, `underlying_seg`, `expiry`                                                                                                                  | None                | 1 req/3 sec |
| **Expiry List**         | `underlying_scrip`, `underlying_seg`                                                                                                                            | None                | 1 req/3 sec |
| **Expired Options**     | `exchange_segment`, `interval`, `security_id`, `instrument`, `expiry_flag`, `expiry_code`, `strike`, `drv_option_type`, `required_data`, `from_date`, `to_date` | None                | Standard    |

---

## Exchange Segments

Common exchange segment values:
- `IDX_I` - Index
- `NSE_EQ` - NSE Equity Cash
- `NSE_FNO` - NSE Futures & Options
- `NSE_CURRENCY` - NSE Currency
- `BSE_EQ` - BSE Equity Cash
- `BSE_FNO` - BSE Futures & Options
- `BSE_CURRENCY` - BSE Currency
- `MCX_COMM` - MCX Commodity

## Instrument Types

Common instrument type values:
- `EQUITY` - Equity
- `INDEX` - Index
- `FUTIDX` - Futures Index
- `FUTSTK` - Futures Stock
- `OPTIDX` - Options Index
- `OPTSTK` - Options Stock
