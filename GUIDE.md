# DhanHQ Client API Guide

This comprehensive guide provides detailed information about each model and their required parameters for making API requests without errors.

## Table of Contents

1. [Order Management Models](#order-management-models)
   - [Order Model](#order-model)
   - [Place Order Contract](#place-order-contract)
   - [Modify Order Contract](#modify-order-contract)
   - [Slice Order Contract](#slice-order-contract)
2. [Data Models](#data-models)
   - [Historical Data Model](#historical-data-model)
   - [Option Chain Model](#option-chain-model)
   - [Margin Calculator Model](#margin-calculator-model)
3. [Constants and Enums](#constants-and-enums)
4. [Validation Rules](#validation-rules)
5. [Error Handling](#error-handling)

---

## Order Management Models

### Order Model

The `Order` model represents trading orders in the DhanHQ system.

#### Available Methods

- `Order.all` - Fetch all orders for the day
- `Order.find(order_id)` - Fetch a specific order by ID
- `Order.find_by_correlation(correlation_id)` - Fetch order by correlation ID
- `Order.place(params)` - Place a new order
- `Order.create(params)` - Create and save a new order

#### Instance Methods

- `order.modify(new_params)` - Modify an existing order
- `order.cancel` - Cancel the order
- `order.refresh` - Fetch latest order details
- `order.save` - Save the order
- `order.destroy` - Cancel the order

---

### Place Order Contract

Used for placing new orders. Validates all required parameters before order placement.

#### Required Parameters

| Parameter          | Type    | Description         | Validation                                                                                           |
| ------------------ | ------- | ------------------- | ---------------------------------------------------------------------------------------------------- |
| `transaction_type` | String  | BUY or SELL         | Must be one of: `BUY`, `SELL`                                                                        |
| `exchange_segment` | String  | Exchange segment    | Must be one of: `NSE_EQ`, `NSE_FNO`, `NSE_CURRENCY`, `BSE_EQ`, `BSE_FNO`, `BSE_CURRENCY`, `MCX_COMM` |
| `product_type`     | String  | Product type        | Must be one of: `CNC`, `INTRADAY`, `MARGIN`, `MTF`, `CO`, `BO`                                       |
| `order_type`       | String  | Order type          | Must be one of: `LIMIT`, `MARKET`, `STOP_LOSS`, `STOP_LOSS_MARKET`                                   |
| `validity`         | String  | Order validity      | Must be one of: `DAY`, `IOC`                                                                         |
| `security_id`      | String  | Security identifier | Required string                                                                                      |
| `quantity`         | Integer | Order quantity      | Must be greater than 0                                                                               |

#### Optional Parameters

| Parameter            | Type    | Description                   | Validation                                                                               |
| -------------------- | ------- | ----------------------------- | ---------------------------------------------------------------------------------------- |
| `correlation_id`     | String  | Tracking identifier           | Max 25 characters                                                                        |
| `disclosed_quantity` | Integer | Disclosed quantity            | Must be >= 0, cannot exceed 30% of total quantity                                        |
| `trading_symbol`     | String  | Trading symbol                | Optional string                                                                          |
| `price`              | Float   | Order price                   | Must be > 0, **Required for LIMIT orders**                                               |
| `trigger_price`      | Float   | Trigger price                 | Must be > 0, **Required for STOP_LOSS orders**                                           |
| `after_market_order` | Boolean | After market order flag       | Optional boolean                                                                         |
| `amo_time`           | String  | AMO timing                    | Must be one of: `OPEN`, `OPEN_30`, `OPEN_60`, **Required if after_market_order is true** |
| `bo_profit_value`    | Float   | Bracket order profit value    | Must be > 0, **Required for BO product type**                                            |
| `bo_stop_loss_value` | Float   | Bracket order stop loss value | Must be > 0, **Required for BO product type**                                            |
| `drv_expiry_date`    | String  | Derivative expiry date        | Optional string                                                                          |
| `drv_option_type`    | String  | Option type                   | Must be one of: `CALL`, `PUT`, `NA`                                                      |
| `drv_strike_price`   | Float   | Strike price                  | Must be > 0                                                                              |

#### Example Usage

```ruby
# Basic LIMIT order
order_params = {
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "CNC",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "1333",
  quantity: 10,
  price: 150.0
}

order = DhanHQ::Models::Order.place(order_params)
```

```ruby
# STOP_LOSS order
stop_loss_params = {
  transaction_type: "SELL",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "STOP_LOSS",
  validity: "DAY",
  security_id: "1333",
  quantity: 10,
  price: 140.0,
  trigger_price: 145.0
}

order = DhanHQ::Models::Order.place(stop_loss_params)
```

```ruby
# Bracket Order (BO)
bracket_order_params = {
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "BO",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "1333",
  quantity: 10,
  price: 150.0,
  bo_profit_value: 160.0,
  bo_stop_loss_value: 140.0
}

order = DhanHQ::Models::Order.place(bracket_order_params)
```

```ruby
# After Market Order (AMO)
amo_params = {
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "CNC",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "1333",
  quantity: 10,
  price: 150.0,
  after_market_order: true,
  amo_time: "OPEN"
}

order = DhanHQ::Models::Order.place(amo_params)
```

---

### Modify Order Contract

Used for modifying existing orders. Requires order ID and at least one field to modify.

#### Required Parameters

| Parameter      | Type   | Description        | Validation      |
| -------------- | ------ | ------------------ | --------------- |
| `dhanClientId` | String | Client ID          | Required string |
| `orderId`      | String | Order ID to modify | Required string |

#### Optional Parameters (At least one required)

| Parameter           | Type    | Description            | Validation                                                         |
| ------------------- | ------- | ---------------------- | ------------------------------------------------------------------ |
| `orderType`         | String  | New order type         | Must be one of: `LIMIT`, `MARKET`, `STOP_LOSS`, `STOP_LOSS_MARKET` |
| `quantity`          | Integer | New quantity           | Must be > 0                                                        |
| `price`             | Float   | New price              | Must be > 0                                                        |
| `triggerPrice`      | Float   | New trigger price      | Must be > 0                                                        |
| `disclosedQuantity` | Integer | New disclosed quantity | Must be >= 0                                                       |
| `validity`          | String  | New validity           | Must be one of: `DAY`, `IOC`                                       |

#### Example Usage

```ruby
# Modify order quantity and price
modify_params = {
  dhanClientId: "123456",
  orderId: "ORDER123",
  quantity: 20,
  price: 155.0
}

# Using the Order model
order = DhanHQ::Models::Order.find("ORDER123")
modified_order = order.modify(modify_params)
```

---

### Slice Order Contract

Used for slicing orders into multiple parts. Similar to Place Order but with additional validity options.

#### Required Parameters

| Parameter         | Type    | Description         | Validation                                                                                           |
| ----------------- | ------- | ------------------- | ---------------------------------------------------------------------------------------------------- |
| `transactionType` | String  | BUY or SELL         | Must be one of: `BUY`, `SELL`                                                                        |
| `exchangeSegment` | String  | Exchange segment    | Must be one of: `NSE_EQ`, `NSE_FNO`, `NSE_CURRENCY`, `BSE_EQ`, `BSE_FNO`, `BSE_CURRENCY`, `MCX_COMM` |
| `productType`     | String  | Product type        | Must be one of: `CNC`, `INTRADAY`, `MARGIN`, `MTF`, `CO`, `BO`                                       |
| `orderType`       | String  | Order type          | Must be one of: `LIMIT`, `MARKET`, `STOP_LOSS`, `STOP_LOSS_MARKET`                                   |
| `validity`        | String  | Order validity      | Must be one of: `DAY`, `IOC`, `GTC`, `GTD`                                                           |
| `securityId`      | String  | Security identifier | Required string                                                                                      |
| `quantity`        | Integer | Order quantity      | Must be greater than 0                                                                               |

#### Optional Parameters

Same as Place Order Contract, with additional validity options (`GTC`, `GTD`).

#### Example Usage

```ruby
# Slice order with GTC validity
slice_params = {
  transactionType: "BUY",
  exchangeSegment: "NSE_EQ",
  productType: "CNC",
  orderType: "LIMIT",
  validity: "GTC",
  securityId: "1333",
  quantity: 100,
  price: 150.0
}

# Using the Order model
order = DhanHQ::Models::Order.find("ORDER123")
sliced_order = order.slice_order(slice_params)
```

---

## Data Models

### Historical Data Model

Fetches historical market data for instruments.

#### Methods

- `HistoricalData.daily(params)` - Fetch daily historical data
- `HistoricalData.intraday(params)` - Fetch intraday historical data

#### Required Parameters

| Parameter          | Type   | Description         | Validation                                                                                                        |
| ------------------ | ------ | ------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `security_id`      | String | Security identifier | Required string                                                                                                   |
| `exchange_segment` | String | Exchange segment    | Must be one of: `NSE_EQ`, `NSE_FNO`, `NSE_CURRENCY`, `BSE_EQ`, `BSE_FNO`, `BSE_CURRENCY`, `MCX_COMM`, `IDX_I`     |
| `instrument`       | String | Instrument type     | Must be one of: `INDEX`, `FUTIDX`, `OPTIDX`, `EQUITY`, `FUTSTK`, `OPTSTK`, `FUTCOM`, `OPTFUT`, `FUTCUR`, `OPTCUR` |
| `from_date`        | String | Start date          | Format: `YYYY-MM-DD`                                                                                              |
| `to_date`          | String | End date            | Format: `YYYY-MM-DD`                                                                                              |

#### Optional Parameters

| Parameter     | Type    | Description                 | Validation                                 |
| ------------- | ------- | --------------------------- | ------------------------------------------ |
| `expiry_code` | Integer | Expiry code for derivatives | Must be one of: `0`, `1`, `2`              |
| `interval`    | String  | Time interval for intraday  | Must be one of: `1`, `5`, `15`, `25`, `60` |

#### Example Usage

```ruby
# Daily historical data
daily_params = {
  security_id: "1333",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  from_date: "2024-01-01",
  to_date: "2024-01-31"
}

daily_data = DhanHQ::Models::HistoricalData.daily(daily_params)
# Returns: { open: [...], high: [...], low: [...], close: [...], volume: [...], timestamp: [...] }
```

```ruby
# Intraday historical data
intraday_params = {
  security_id: "1333",
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  interval: "15",
  from_date: "2024-01-15",
  to_date: "2024-01-15"
}

intraday_data = DhanHQ::Models::HistoricalData.intraday(intraday_params)
```

---

### Option Chain Model

Fetches option chain data and expiry lists for derivatives.

#### Methods

- `OptionChain.fetch(params)` - Fetch option chain data
- `OptionChain.fetch_expiry_list(params)` - Fetch expiry list

#### Required Parameters

| Parameter          | Type    | Description               | Validation                                              |
| ------------------ | ------- | ------------------------- | ------------------------------------------------------- |
| `underlying_scrip` | Integer | Security ID of underlying | Required integer                                        |
| `underlying_seg`   | String  | Underlying segment        | Must be one of: `IDX_I`, `NSE_FNO`, `BSE_FNO`, `MCX_FO` |
| `expiry`           | String  | Expiry date               | Format: `YYYY-MM-DD`, must be valid date                |

#### Example Usage

```ruby
# Fetch option chain
option_params = {
  underlying_scrip: 1333,
  underlying_seg: "NSE_FNO",
  expiry: "2024-02-29"
}

option_chain = DhanHQ::Models::OptionChain.fetch(option_params)
# Returns filtered option chain with valid strikes
```

```ruby
# Fetch expiry list
expiry_params = {
  underlying_scrip: 1333,
  underlying_seg: "NSE_FNO"
}

expiry_list = DhanHQ::Models::OptionChain.fetch_expiry_list(expiry_params)
# Returns array of expiry dates
```

---

### Margin Calculator Model

Calculates margin requirements for orders.

#### Required Parameters

| Parameter         | Type    | Description         | Validation                                                     |
| ----------------- | ------- | ------------------- | -------------------------------------------------------------- |
| `dhanClientId`    | String  | Client ID           | Required string                                                |
| `exchangeSegment` | String  | Exchange segment    | Must be one of: `NSE_EQ`, `NSE_FNO`, `BSE_EQ`                  |
| `transactionType` | String  | Transaction type    | Must be one of: `BUY`, `SELL`                                  |
| `quantity`        | Integer | Order quantity      | Must be greater than 0                                         |
| `productType`     | String  | Product type        | Must be one of: `CNC`, `INTRADAY`, `MARGIN`, `MTF`, `CO`, `BO` |
| `securityId`      | String  | Security identifier | Required string                                                |
| `price`           | Float   | Order price         | Must be greater than 0                                         |

#### Optional Parameters

| Parameter      | Type  | Description   | Validation     |
| -------------- | ----- | ------------- | -------------- |
| `triggerPrice` | Float | Trigger price | Optional float |

#### Example Usage

```ruby
# Calculate margin for a trade
margin_params = {
  dhanClientId: "123456",
  exchangeSegment: "NSE_EQ",
  transactionType: "BUY",
  quantity: 10,
  productType: "INTRADAY",
  securityId: "1333",
  price: 150.0
}

margin_info = DhanHQ::Models::Margin.calculate(margin_params)
```

---

## Constants and Enums

### Transaction Types
- `BUY` - Buy transaction
- `SELL` - Sell transaction

### Exchange Segments
- `NSE_EQ` - NSE Equity
- `NSE_FNO` - NSE F&O
- `NSE_CURRENCY` - NSE Currency
- `BSE_EQ` - BSE Equity
- `BSE_FNO` - BSE F&O
- `BSE_CURRENCY` - BSE Currency
- `MCX_COMM` - MCX Commodity
- `IDX_I` - Index

### Product Types
- `CNC` - Cash and Carry
- `INTRADAY` - Intraday
- `MARGIN` - Margin
- `MTF` - Margin Trading Facility
- `CO` - Cover Order
- `BO` - Bracket Order

### Order Types
- `LIMIT` - Limit Order
- `MARKET` - Market Order
- `STOP_LOSS` - Stop Loss Order
- `STOP_LOSS_MARKET` - Stop Loss Market Order

### Validity Types
- `DAY` - Day validity
- `IOC` - Immediate or Cancel
- `GTC` - Good Till Cancelled (for slice orders)
- `GTD` - Good Till Date (for slice orders)

### Instruments
- `INDEX` - Index
- `FUTIDX` - Future Index
- `OPTIDX` - Option Index
- `EQUITY` - Equity
- `FUTSTK` - Future Stock
- `OPTSTK` - Option Stock
- `FUTCOM` - Future Commodity
- `OPTFUT` - Option Future
- `FUTCUR` - Future Currency
- `OPTCUR` - Option Currency

---

## Validation Rules

### Conditional Requirements

1. **Price Field**: Required for `LIMIT` orders
2. **Trigger Price**: Required for `STOP_LOSS` and `STOP_LOSS_MARKET` orders
3. **AMO Time**: Required when `after_market_order` is `true`
4. **Bracket Order Fields**: Both `bo_profit_value` and `bo_stop_loss_value` are required for `BO` product type
5. **Disclosed Quantity**: Cannot exceed 30% of total quantity
6. **Modify Order**: At least one field must be provided for modification

### Format Requirements

1. **Dates**: Must be in `YYYY-MM-DD` format
2. **Correlation ID**: Maximum 25 characters
3. **Numeric Values**: Must be positive where specified
4. **Expiry Dates**: Must be valid dates

---

## Error Handling

The DhanHQ client includes comprehensive error handling with specific error types:

### Error Types

- `InvalidAuthenticationError` (DH-901)
- `InvalidAccessError` (DH-902)
- `UserAccountError` (DH-903)
- `RateLimitError` (DH-904)
- `InputExceptionError` (DH-905)
- `OrderError` (DH-906)
- `DataError` (DH-907)
- `InternalServerError` (DH-908)
- `NetworkError` (DH-909)
- `OtherError` (DH-910)

### Common Error Codes

- `800` - Internal Server Error
- `804` - Too many instruments
- `805` - Too many requests (Rate Limit)
- `806` - Data API not subscribed
- `807` - Token expired
- `808` - Authentication failed
- `809` - Invalid token
- `810` - Invalid Client ID
- `811` - Invalid expiry date
- `812` - Invalid date format
- `813` - Invalid security ID
- `814` - Invalid request

### Error Handling Example

```ruby
begin
  order = DhanHQ::Models::Order.place(order_params)
  if order
    puts "Order placed successfully: #{order.order_id}"
  else
    puts "Failed to place order"
  end
rescue DhanHQ::InvalidAuthenticationError => e
  puts "Authentication failed: #{e.message}"
rescue DhanHQ::OrderError => e
  puts "Order error: #{e.message}"
rescue DhanHQ::RateLimitError => e
  puts "Rate limit exceeded: #{e.message}"
rescue => e
  puts "Unexpected error: #{e.message}"
end
```

---

## Best Practices

1. **Always validate parameters** before making API calls
2. **Handle errors gracefully** with appropriate error types
3. **Use correlation IDs** for tracking orders
4. **Check order status** after placement/modification
5. **Respect rate limits** to avoid throttling
6. **Use appropriate product types** based on your trading strategy
7. **Validate dates** before making historical data requests
8. **Check margin requirements** before placing large orders

---

This guide provides comprehensive information about all available models and their parameters. Always refer to the official DhanHQ API documentation for the most up-to-date information and additional details.
