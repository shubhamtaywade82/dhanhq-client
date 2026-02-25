# DhanHQ API v2 Constants Reference

Complete reference of all constants available in the DhanHQ API v2. These constants should be defined in your `dhanhq-client` Ruby gem.

**Source:** [DhanHQ API v2 Documentation](https://dhanhq.co/docs/v2/)  
**Reference:** [Annexure](https://dhanhq.co/docs/v2/annexure/)

---

## Exchange Segments

Exchange segments for different markets and instruments.

| Constant | Value | Description | Enum Value |
|----------|-------|-------------|------------|
| `IDX_I` | `"IDX_I"` | Index - Index Value | 0 |
| `NSE_EQ` | `"NSE_EQ"` | NSE - Equity Cash | 1 |
| `NSE_FNO` | `"NSE_FNO"` | NSE - Futures & Options | 2 |
| `NSE_CURRENCY` | `"NSE_CURRENCY"` | NSE - Currency | 3 |
| `BSE_EQ` | `"BSE_EQ"` | BSE - Equity Cash | 4 |
| `MCX_COMM` | `"MCX_COMM"` | MCX - Commodity | 5 |
| `BSE_CURRENCY` | `"BSE_CURRENCY"` | BSE - Currency | 7 |
| `BSE_FNO` | `"BSE_FNO"` | BSE - Futures & Options | 8 |

---

## Product Types

Product types for order placement.

**Note:** CO & BO product types are valid only for INTRADAY.

| Constant | Value | Description |
|----------|-------|-------------|
| `CNC` | `"CNC"` | Cash & Carry for equity deliveries |
| `INTRADAY` | `"INTRADAY"` | Intraday for Equity, Futures & Options |
| `MARGIN` | `"MARGIN"` | Carry Forward in Futures & Options |
| `MTF` | `"MTF"` | Margin Trading Facility |
| `CO` | `"CO"` | Cover Order (Intraday only) |
| `BO` | `"BO"` | Bracket Order (Intraday only) |

---

## Transaction Types

Buy/Sell transaction types.

| Constant | Value | Description |
|----------|-------|-------------|
| `BUY` | `"BUY"` | Buy transaction |
| `SELL` | `"SELL"` | Sell transaction |

---

## Order Types

Order types for placement and modification.

| Constant | Value | Description |
|----------|-------|-------------|
| `LIMIT` | `"LIMIT"` | Limit order |
| `MARKET` | `"MARKET"` | Market order |
| `STOP_LOSS` | `"STOP_LOSS"` | Stop loss limit order |
| `STOP_LOSS_MARKET` | `"STOP_LOSS_MARKET"` | Stop loss market order |

---

## Validity Types

Order validity types.

| Constant | Value | Description |
|----------|-------|-------------|
| `DAY` | `"DAY"` | Valid for the day |
| `IOC` | `"IOC"` | Immediate or Cancel |

---

## Order Status

Order status values across the lifecycle.

| Constant | Value | Description |
|----------|-------|-------------|
| `TRANSIT` | `"TRANSIT"` | Did not reach the exchange server |
| `PENDING` | `"PENDING"` | Awaiting execution |
| `CLOSED` | `"CLOSED"` | Used for Super Order, once both entry and exit orders are placed |
| `TRIGGERED` | `"TRIGGERED"` | Used for Super Order, if Target or Stop Loss leg is triggered |
| `REJECTED` | `"REJECTED"` | Rejected by broker/exchange |
| `CANCELLED` | `"CANCELLED"` | Cancelled by user |
| `PART_TRADED` | `"PART_TRADED"` | Partial Quantity traded successfully |
| `TRADED` | `"TRADED"` | Executed successfully |
| `EXPIRED` | `"EXPIRED"` | Order expired |

---

## After Market Order Time

AMO (After Market Order) timing options.

| Constant | Value | Description |
|----------|-------|-------------|
| `PRE_OPEN` | `"PRE_OPEN"` | AMO pumped at pre-market session |
| `OPEN` | `"OPEN"` | AMO pumped at market open |
| `OPEN_30` | `"OPEN_30"` | AMO pumped 30 minutes after market open |
| `OPEN_60` | `"OPEN_60"` | AMO pumped 60 minutes after market open |

---

## Expiry Code

Expiry codes for futures and options contracts.

| Constant | Value | Description |
|----------|-------|-------------|
| `CURRENT` | `0` | Current Expiry/Near Expiry |
| `NEXT` | `1` | Next Expiry |
| `FAR` | `2` | Far Expiry |

---

## Instrument Types

Instrument types across different exchanges.

| Constant | Value | Description |
|----------|-------|-------------|
| `INDEX` | `"INDEX"` | Index |
| `FUTIDX` | `"FUTIDX"` | Futures of Index |
| `OPTIDX` | `"OPTIDX"` | Options of Index |
| `EQUITY` | `"EQUITY"` | Equity |
| `FUTSTK` | `"FUTSTK"` | Futures of Stock |
| `OPTSTK` | `"OPTSTK"` | Options of Stock |
| `FUTCOM` | `"FUTCOM"` | Futures of Commodity |
| `OPTFUT` | `"OPTFUT"` | Options of Commodity Futures |
| `FUTCUR` | `"FUTCUR"` | Futures of Currency |
| `OPTCUR` | `"OPTCUR"` | Options of Currency |

---

## Option Types

Option types for derivatives trading.

| Constant | Value | Description |
|----------|-------|-------------|
| `CALL` | `"CALL"` | Call option |
| `PUT` | `"PUT"` | Put option |

---

## Leg Names

Leg names for Bracket Orders, Cover Orders, Super Orders, and Forever Orders.

| Constant | Value | Description |
|----------|-------|-------------|
| `ENTRY_LEG` | `"ENTRY_LEG"` | Entry leg |
| `TARGET_LEG` | `"TARGET_LEG"` | Target/profit leg |
| `STOP_LOSS_LEG` | `"STOP_LOSS_LEG"` | Stop loss leg |

---

## Order Flags

Order flags for Forever Orders.

| Constant | Value | Description |
|----------|-------|-------------|
| `SINGLE` | `"SINGLE"` | Single order |
| `OCO` | `"OCO"` | One-Cancels-the-Other order |

---

## Position Types

Position types for position conversion.

| Constant | Value | Description |
|----------|-------|-------------|
| `LONG` | `"LONG"` | Long position |
| `SHORT` | `"SHORT"` | Short position |

---

## Feed Request Codes (WebSocket)

Feed request codes for Live Market Feed WebSocket subscription.

| Constant | Value | Description |
|----------|-------|-------------|
| `CONNECT` | `11` | Connect Feed |
| `DISCONNECT` | `12` | Disconnect Feed |
| `SUBSCRIBE_TICKER` | `15` | Subscribe - Ticker Packet |
| `UNSUBSCRIBE_TICKER` | `16` | Unsubscribe - Ticker Packet |
| `SUBSCRIBE_QUOTE` | `17` | Subscribe - Quote Packet |
| `UNSUBSCRIBE_QUOTE` | `18` | Unsubscribe - Quote Packet |
| `SUBSCRIBE_FULL` | `21` | Subscribe - Full Packet |
| `UNSUBSCRIBE_FULL` | `22` | Unsubscribe - Full Packet |
| `SUBSCRIBE_DEPTH` | `23` | Subscribe - Full Market Depth |
| `UNSUBSCRIBE_DEPTH` | `24` | Unsubscribe - Full Market Depth |

---

## Feed Response Codes (WebSocket)

Feed response codes for Live Market Feed WebSocket.

| Constant | Value | Description |
|----------|-------|-------------|
| `INDEX_PACKET` | `1` | Index Packet |
| `TICKER_PACKET` | `2` | Ticker Packet |
| `QUOTE_PACKET` | `4` | Quote Packet |
| `OI_PACKET` | `5` | OI (Open Interest) Packet |
| `PREV_CLOSE_PACKET` | `6` | Previous Close Packet |
| `MARKET_STATUS_PACKET` | `7` | Market Status Packet |
| `FULL_PACKET` | `8` | Full Packet (Quote + OI + Depth) |
| `FEED_DISCONNECT` | `50` | Feed Disconnect |

---

## Conditional Triggers

### Comparison Types

Comparison types for conditional trigger alerts.

| Constant | Value | Description | Mandatory Fields |
|----------|-------|-------------|------------------|
| `TECHNICAL_WITH_VALUE` | `"TECHNICAL_WITH_VALUE"` | Compare technical indicator against fixed value | indicatorName, operator, timeFrame, comparingValue |
| `TECHNICAL_WITH_INDICATOR` | `"TECHNICAL_WITH_INDICATOR"` | Compare technical indicator against another indicator | indicatorName, operator, timeFrame, comparingIndicatorName |
| `TECHNICAL_WITH_CLOSE` | `"TECHNICAL_WITH_CLOSE"` | Compare technical indicator with closing price | indicatorName, operator, timeFrame |
| `PRICE_WITH_VALUE` | `"PRICE_WITH_VALUE"` | Compare market price against fixed value | operator, comparingValue |

### Indicator Names

Technical indicators for conditional triggers.

#### Simple Moving Averages

| Constant | Value | Description |
|----------|-------|-------------|
| `SMA_5` | `"SMA_5"` | Simple Moving Average (5 periods) |
| `SMA_10` | `"SMA_10"` | Simple Moving Average (10 periods) |
| `SMA_20` | `"SMA_20"` | Simple Moving Average (20 periods) |
| `SMA_50` | `"SMA_50"` | Simple Moving Average (50 periods) |
| `SMA_100` | `"SMA_100"` | Simple Moving Average (100 periods) |
| `SMA_200` | `"SMA_200"` | Simple Moving Average (200 periods) |

#### Exponential Moving Averages

| Constant | Value | Description |
|----------|-------|-------------|
| `EMA_5` | `"EMA_5"` | Exponential Moving Average (5 periods) |
| `EMA_10` | `"EMA_10"` | Exponential Moving Average (10 periods) |
| `EMA_20` | `"EMA_20"` | Exponential Moving Average (20 periods) |
| `EMA_50` | `"EMA_50"` | Exponential Moving Average (50 periods) |
| `EMA_100` | `"EMA_100"` | Exponential Moving Average (100 periods) |
| `EMA_200` | `"EMA_200"` | Exponential Moving Average (200 periods) |

#### Other Indicators

| Constant | Value | Description |
|----------|-------|-------------|
| `BB_UPPER` | `"BB_UPPER"` | Upper Bollinger Band |
| `BB_LOWER` | `"BB_LOWER"` | Lower Bollinger Band |
| `RSI_14` | `"RSI_14"` | Relative Strength Index (14 periods) |
| `ATR_14` | `"ATR_14"` | Average True Range (14 periods) |
| `STOCHASTIC` | `"STOCHASTIC"` | Stochastic Oscillator |
| `STOCHRSI_14` | `"STOCHRSI_14"` | Stochastic RSI (14 periods) |
| `MACD_26` | `"MACD_26"` | MACD long-term component |
| `MACD_12` | `"MACD_12"` | MACD short-term component |
| `MACD_HIST` | `"MACD_HIST"` | MACD histogram |

### Operators

Operators for conditional trigger comparisons.

| Constant | Value | Description |
|----------|-------|-------------|
| `CROSSING_UP` | `"CROSSING_UP"` | Crosses above |
| `CROSSING_DOWN` | `"CROSSING_DOWN"` | Crosses below |
| `CROSSING_ANY_SIDE` | `"CROSSING_ANY_SIDE"` | Crosses either side |
| `GREATER_THAN` | `"GREATER_THAN"` | Greater than |
| `LESS_THAN` | `"LESS_THAN"` | Less than |
| `GREATER_THAN_EQUAL` | `"GREATER_THAN_EQUAL"` | Greater than or equal |
| `LESS_THAN_EQUAL` | `"LESS_THAN_EQUAL"` | Less than or equal |
| `EQUAL` | `"EQUAL"` | Equal |
| `NOT_EQUAL` | `"NOT_EQUAL"` | Not equal |

### Trigger Status

Status values for conditional triggers.

| Constant | Value | Description |
|----------|-------|-------------|
| `ACTIVE` | `"ACTIVE"` | Alert is currently active |
| `TRIGGERED` | `"TRIGGERED"` | Alert condition met |
| `EXPIRED` | `"EXPIRED"` | Alert expired |
| `CANCELLED` | `"CANCELLED"` | Alert cancelled |

---

## Error Codes

### Trading API Error Codes

Error codes for Trading APIs (DH-900 series).

| Constant | Code | Description |
|----------|------|-------------|
| `INVALID_AUTHENTICATION` | `"DH-901"` | Client ID or access token invalid/expired |
| `INVALID_ACCESS` | `"DH-902"` | User not subscribed to Data APIs or no Trading API access |
| `USER_ACCOUNT` | `"DH-903"` | User account errors (segments, requirements) |
| `RATE_LIMIT` | `"DH-904"` | Rate limit exceeded |
| `INPUT_EXCEPTION` | `"DH-905"` | Missing fields, bad parameter values |
| `ORDER_ERROR` | `"DH-906"` | Incorrect order request |
| `DATA_ERROR` | `"DH-907"` | Unable to fetch data, incorrect parameters |
| `INTERNAL_SERVER_ERROR` | `"DH-908"` | Server processing error |
| `NETWORK_ERROR` | `"DH-909"` | Network communication error |
| `OTHERS` | `"DH-910"` | Other errors |

### Data API Error Codes

Error codes for Data APIs (800 series).

| Constant | Code | Description |
|----------|------|-------------|
| `INTERNAL_SERVER_ERROR` | `800` | Internal Server Error |
| `INSTRUMENTS_LIMIT` | `804` | Requested instruments exceed limit |
| `TOO_MANY_REQUESTS` | `805` | Rate limit exceeded |
| `NOT_SUBSCRIBED` | `806` | Data APIs not subscribed |
| `TOKEN_EXPIRED` | `807` | Access token expired |
| `AUTH_FAILED` | `808` | Client ID or Access Token invalid |
| `INVALID_TOKEN` | `809` | Access token invalid |
| `INVALID_CLIENT_ID` | `810` | Client ID invalid |
| `INVALID_EXPIRY_DATE` | `811` | Invalid Expiry Date |
| `INVALID_DATE_FORMAT` | `812` | Invalid Date Format |
| `INVALID_SECURITY_ID` | `813` | Invalid SecurityId |
| `INVALID_REQUEST` | `814` | Invalid Request |

---

## Usage Examples

### Basic Order Placement

```ruby
require 'dhanhq'

# Using constants
DhanHQ.place_order(
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  product_type: DhanHQ::Constants::ProductType::INTRADAY,
  order_type: DhanHQ::Constants::OrderType::MARKET,
  validity: DhanHQ::Constants::Validity::DAY,
  security_id: "1333",
  quantity: 10
)
```

### Conditional Trigger

```ruby
# Create a conditional trigger when RSI crosses above 30
DhanHQ.create_trigger(
  comparison_type: DhanHQ::Constants::ComparisonType::TECHNICAL_WITH_VALUE,
  indicator_name: DhanHQ::Constants::IndicatorName::RSI_14,
  operator: DhanHQ::Constants::Operator::CROSSING_UP,
  comparing_value: 30
)
```

### WebSocket Subscription

```ruby
# Subscribe to ticker feed
DhanHQ::WebSocket.send_request(
  request_code: DhanHQ::Constants::FeedRequest::SUBSCRIBE_TICKER,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  security_id: "1333"
)
```

---

## Implementation Notes

### Module Structure

The constants should be organized in nested modules:

```ruby
module DhanHQ
  module Constants
    module ExchangeSegment
      NSE_EQ = "NSE_EQ"
      # ...
    end
    
    module ProductType
      CNC = "CNC"
      # ...
    end
    # ... other constant modules
  end
end
```

### Validation Helpers

Consider adding validation helpers:

```ruby
module DhanHQ
  module Constants
    def self.valid?(module_name, value)
      const_get(module_name)::ALL.include?(value)
    end
    
    def self.all_for(module_name)
      const_get(module_name)::ALL
    end
  end
end

# Usage
DhanHQ::Constants.valid?(:ExchangeSegment, "NSE_EQ") # => true
DhanHQ::Constants.all_for(:OrderType) # => ["LIMIT", "MARKET", ...]
```

---

## Rate Limits

| API Type | Per Second | Per Minute | Per Hour | Per Day |
|----------|------------|------------|----------|---------|
| Order APIs | 10 | 250 | 1,000 | 7,000 |
| Data APIs | 5 | - | - | 100,000 |
| Quote APIs | 1 | Unlimited | Unlimited | Unlimited |
| Non Trading APIs | 20 | Unlimited | Unlimited | Unlimited |

**Note:** Order modifications are capped at 25 modifications per order.

---

## References

- [DhanHQ API v2 Documentation](https://dhanhq.co/docs/v2/)
- [Annexure - Constants Reference](https://dhanhq.co/docs/v2/annexure/)
- [Orders API](https://dhanhq.co/docs/v2/orders/)
- [Super Order API](https://dhanhq.co/docs/v2/super-order/)
- [Forever Order API](https://dhanhq.co/docs/v2/forever/)
- [Conditional Triggers API](https://dhanhq.co/docs/v2/conditional-trigger/)
- [Live Market Feed](https://dhanhq.co/docs/v2/live-market-feed/)
