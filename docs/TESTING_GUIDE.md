# DhanHQ Client Gem - Comprehensive Testing Guide

This guide provides interactive testing examples for all features of the DhanHQ client gem. You can use these examples in `bin/console` to test and explore the gem's functionality.

## Table of Contents

1. [Setup & Configuration](#setup--configuration)
2. [WebSocket Testing](#websocket-testing)
   - [Market Feed WebSocket](#market-feed-websocket)
   - [Order Update WebSocket](#order-update-websocket)
   - [Market Depth WebSocket](#market-depth-websocket)
3. [Model Testing](#model-testing)
   - [Orders](#orders)
   - [Positions](#positions)
   - [Holdings](#holdings)
   - [Funds](#funds)
   - [Trades](#trades)
   - [Profile](#profile)
   - [Market Feed](#market-feed)
   - [Historical Data](#historical-data)
   - [Option Chain](#option-chain)
   - [Instruments](#instruments)
   - [Super Orders](#super-orders)
   - [Forever Orders (GTT)](#forever-orders-gtt)
   - [EDIS](#edis)
   - [Kill Switch](#kill-switch)
   - [Expired Options Data](#expired-options-data)
   - [Margin Calculator](#margin-calculator)
   - [Ledger Entries](#ledger-entries)
4. [Validation Contracts Testing](#validation-contracts-testing)
5. [Error Handling Testing](#error-handling-testing)
6. [Rate Limiting Testing](#rate-limiting-testing)

---

## Setup & Configuration

### Basic Setup in Console

```ruby
# Start console: bin/console

# Configure from environment variables
DhanHQ.configure_with_env

# Or configure manually
DhanHQ.configure do |config|
  config.client_id = "your_client_id"
  config.access_token = "your_access_token"
  config.ws_user_type = "SELF" # or "PARTNER"
end

# Optional: dynamic token at request time (e.g. from DB or OAuth)
# DhanHQ.configure do |config|
#   config.client_id = ENV["DHAN_CLIENT_ID"]
#   config.access_token_provider = -> { YourTokenStore.active_token }
#   config.on_token_expired = ->(err) { YourTokenStore.refresh! }
# end

# Set log level for debugging
DhanHQ.logger.level = Logger::DEBUG

# Verify configuration
puts "Client ID: #{DhanHQ.configuration.client_id}"
puts "Access Token: #{DhanHQ.configuration.access_token ? 'Set' : 'Not Set'}"
puts "Token provider: #{DhanHQ.configuration.access_token_provider ? 'Set' : 'Not Set'}"
```

### Environment Variables

```ruby
# Check current environment variables
puts "CLIENT_ID: #{ENV['CLIENT_ID']}"
puts "ACCESS_TOKEN: #{ENV['ACCESS_TOKEN'] ? 'Set' : 'Not Set'}"
puts "DHAN_LOG_LEVEL: #{ENV['DHAN_LOG_LEVEL'] || 'INFO'}"
puts "DHAN_CONNECT_TIMEOUT: #{ENV['DHAN_CONNECT_TIMEOUT'] || '10'}"
puts "DHAN_READ_TIMEOUT: #{ENV['DHAN_READ_TIMEOUT'] || '30'}"
```

---

## WebSocket Testing

### Market Feed WebSocket

#### Basic Ticker Subscription

```ruby
# Create market feed WebSocket connection
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "[#{timestamp}] #{tick[:segment]}:#{tick[:security_id]} = ₹#{tick[:ltp]}"
end

# Subscribe to NIFTY (Security ID: 13, Segment: IDX_I)
market_client.subscribe_one(segment: "IDX_I", security_id: "13")

# Subscribe to BANKNIFTY (Security ID: 25, Segment: IDX_I)
market_client.subscribe_one(segment: "IDX_I", security_id: "25")

# Wait for data (in console, you can continue working)
sleep(10)

# Stop connection
market_client.stop
```

#### OHLC Subscription

```ruby
# Create OHLC WebSocket connection
ohlc_client = DhanHQ::WS.connect(mode: :ohlc) do |data|
  puts "OHLC: #{data[:segment]}:#{data[:security_id]}"
  puts "  Open: ₹#{data[:open]}, High: ₹#{data[:high]}, Low: ₹#{data[:low]}, Close: ₹#{data[:close]}"
end

# Subscribe to NIFTY
ohlc_client.subscribe_one(segment: "IDX_I", security_id: "13")

sleep(10)
ohlc_client.stop
```

#### Quote Subscription (Full Market Depth)

```ruby
# Create quote WebSocket connection
quote_client = DhanHQ::WS.connect(mode: :quote) do |data|
  puts "Quote: #{data[:segment]}:#{data[:security_id]}"
  puts "  LTP: ₹#{data[:ltp]}"
  puts "  Volume: #{data[:volume]}"
  puts "  Open Interest: #{data[:oi]}" if data[:oi]
end

# Subscribe to NIFTY
quote_client.subscribe_one(segment: "IDX_I", security_id: "13")

sleep(10)
quote_client.stop
```

#### Multiple Subscriptions

```ruby
# Subscribe to multiple instruments
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  puts "#{tick[:segment]}:#{tick[:security_id]} = ₹#{tick[:ltp]}"
end

# Subscribe to multiple indices
indices = [
  { segment: "IDX_I", security_id: "13" },   # NIFTY
  { segment: "IDX_I", security_id: "25" },   # BANKNIFTY
  { segment: "IDX_I", security_id: "29" },   # NIFTYIT
  { segment: "IDX_I", security_id: "51" }    # SENSEX
]

indices.each do |idx|
  market_client.subscribe_one(segment: idx[:segment], security_id: idx[:security_id])
end

sleep(15)
market_client.stop
```

#### Testing Connection State

```ruby
market_client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts tick[:ltp] }
market_client.subscribe_one(segment: "IDX_I", security_id: "13")

# Check connection state
puts "Connected: #{market_client.connected?}"

sleep(5)
market_client.stop
puts "Connected after stop: #{market_client.connected?}"
```

### Order Update WebSocket

#### Basic Order Tracking

```ruby
# Create order update client
orders_client = DhanHQ::WS::Orders.client

# Track all order updates
orders_client.on(:update) do |order|
  puts "\n📋 Order Update: #{order.order_no}"
  puts "   Symbol: #{order.symbol}"
  puts "   Status: #{order.status}"
  puts "   Quantity: #{order.traded_qty}/#{order.quantity}"
  puts "   Price: ₹#{order.price}"
end

# Start monitoring
orders_client.start
puts "✅ Order tracking started. Place orders to see updates..."

# In console, you can continue working while tracking orders
# Stop when done
# orders_client.stop
```

#### Comprehensive Event Handling

```ruby
orders_client = DhanHQ::WS::Orders.client

# Track status changes
orders_client.on(:status_change) do |data|
  order = data[:order_update]
  puts "\n🔄 Status Change: #{order.order_no}"
  puts "   #{data[:previous_status]} -> #{data[:new_status]}"
end

# Track executions
orders_client.on(:execution) do |data|
  order = data[:order_update]
  puts "\n💰 Execution: #{order.order_no}"
  puts "   Traded: #{data[:previous_traded_qty]} -> #{data[:new_traded_qty]} shares"
end

# Track fully traded orders
orders_client.on(:order_traded) do |order|
  puts "\n✅ Order Fully Executed: #{order.order_no}"
  puts "   Average Price: ₹#{order.avg_traded_price}"
end

# Track rejected orders
orders_client.on(:order_rejected) do |order|
  puts "\n❌ Order Rejected: #{order.order_no}"
  puts "   Reason: #{order.reason_description}"
end

# Track cancelled orders
orders_client.on(:order_cancelled) do |order|
  puts "\n🚫 Order Cancelled: #{order.order_no}"
end

orders_client.start
```

#### Querying Tracked Orders

```ruby
orders_client = DhanHQ::WS::Orders.client
orders_client.start

# Get all tracked orders
all_orders = orders_client.all_orders
puts "Total tracked orders: #{all_orders.size}"

# Get specific order
if all_orders.any?
  order_no = all_orders.keys.first
  order = orders_client.order(order_no)
  puts "Order #{order_no}:"
  puts "  Status: #{order.status}"
  puts "  Symbol: #{order.symbol}"
  puts "  Execution: #{order.execution_percentage}%"
end

# Check if order is tracked
order_no = "112111182045"
if orders_client.tracked?(order_no)
  puts "Order #{order_no} is being tracked"
else
  puts "Order #{order_no} is not tracked"
end
```

### Market Depth WebSocket

#### Basic Market Depth

```ruby
# First, find instruments
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

# Prepare symbols
symbols = []
if reliance
  symbols << {
    symbol: "RELIANCE",
    exchange_segment: reliance.exchange_segment,
    security_id: reliance.security_id
  }
end

if tcs
  symbols << {
    symbol: "TCS",
    exchange_segment: tcs.exchange_segment,
    security_id: tcs.security_id
  }
end

# Create market depth client
depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
  puts "\n📊 Market Depth: #{depth_data[:symbol]}"
  puts "   Best Bid: ₹#{depth_data[:best_bid]}"
  puts "   Best Ask: ₹#{depth_data[:best_ask]}"
  puts "   Spread: ₹#{depth_data[:spread]}"
  puts "   Bid Levels: #{depth_data[:bids].size}"
  puts "   Ask Levels: #{depth_data[:asks].size}"
end

sleep(10)
depth_client.stop
```

---

## Model Testing

### Orders

#### Place Order

```ruby
# Place a market order
order = DhanHQ::Models::Order.place(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "MARKET",
  validity: "DAY",
  security_id: "11536",  # TCS
  quantity: 1
)

puts "Order placed: #{order.order_id}"
puts "Status: #{order.order_status}"
```

#### Place Limit Order

```ruby
# Place a limit order
order = DhanHQ::Models::Order.place(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "11536",
  quantity: 1,
  price: 3500.0
)

puts "Order ID: #{order.order_id}"
```

#### Place Stop Loss Order

```ruby
# Place stop loss order
order = DhanHQ::Models::Order.place(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "STOPLOSS",
  validity: "DAY",
  security_id: "11536",
  quantity: 1,
  price: 3500.0,
  trigger_price: 3450.0
)

puts "Order ID: #{order.order_id}"
```

#### Find Order

```ruby
# Find order by ID
order = DhanHQ::Models::Order.find("112111182045")
puts "Order Status: #{order.order_status}"
puts "Symbol: #{order.trading_symbol}"
puts "Quantity: #{order.quantity}"
puts "Traded Qty: #{order.traded_qty}"
```

#### Find Order by Correlation ID

```ruby
# Find order by correlation ID
correlation_id = "my-unique-id-123"
order = DhanHQ::Models::Order.find_by_correlation(correlation_id)
if order
  puts "Order found: #{order.order_id}"
else
  puts "Order not found"
end
```

#### Get All Orders

```ruby
# Get all orders for the day
orders = DhanHQ::Models::Order.all
puts "Total orders: #{orders.size}"

# Filter pending orders
pending = orders.select { |o| o.order_status == "PENDING" }
puts "Pending orders: #{pending.size}"

# Filter executed orders
executed = orders.select { |o| o.order_status == "TRADED" }
puts "Executed orders: #{executed.size}"
```

#### Modify Order

```ruby
# Find order
order = DhanHQ::Models::Order.find("112111182045")

# Modify price and quantity
if order.modify(price: 3501.0, quantity: 2)
  puts "Order modified successfully"
  order.refresh
  puts "New price: #{order.price}"
  puts "New quantity: #{order.quantity}"
else
  puts "Order modification failed"
end
```

#### Cancel Order

```ruby
# Cancel order
order = DhanHQ::Models::Order.find("112111182045")
if order.cancel
  puts "Order cancelled successfully"
else
  puts "Order cancellation failed"
end
```

#### Slice Order

```ruby
# Slice order into multiple smaller orders
order = DhanHQ::Models::Order.find("112111182045")

# Slice into 3 orders of 10 shares each
sliced_orders = order.slice_order(
  slice_count: 3,
  slice_size: 10,
  price: 3500.0
)

puts "Created #{sliced_orders.size} sliced orders"
sliced_orders.each do |sliced_order|
  puts "  Order ID: #{sliced_order.order_id}, Quantity: #{sliced_order.quantity}"
end
```

#### Create Order (ActiveRecord-style)

```ruby
# Create order instance
order = DhanHQ::Models::Order.new(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "MARKET",
  validity: "DAY",
  security_id: "11536",
  quantity: 1
)

# Save (places order)
if order.save
  puts "Order placed: #{order.order_id}"
else
  puts "Order placement failed"
end
```

### Positions

#### Get All Positions

```ruby
# Get all positions
positions = DhanHQ::Models::Position.all
puts "Total positions: #{positions.size}"

# Filter by exchange
nse_positions = positions.select { |p| p.exchange_segment == "NSE_EQ" }
puts "NSE positions: #{nse_positions.size}"

# Filter long positions
long_positions = positions.select { |p| p.net_qty > 0 }
puts "Long positions: #{long_positions.size}"
```

#### Convert Position

```ruby
# Find position
position = DhanHQ::Models::Position.all.first

# Convert position (e.g., from INTRADAY to DELIVERY)
if position
  result = position.convert(
    dhan_client_id: "1000000003",
    from_product_type: "INTRADAY",
    to_product_type: "MARGIN",
    quantity: position.net_qty.abs
  )
  
  if result
    puts "Position converted successfully"
  else
    puts "Position conversion failed"
  end
end
```

### Holdings

#### Get All Holdings

```ruby
# Get all holdings
holdings = DhanHQ::Models::Holding.all
puts "Total holdings: #{holdings.size}"

# Display holdings
holdings.each do |holding|
  puts "#{holding.trading_symbol}: #{holding.quantity} shares"
  puts "  Average Price: ₹#{holding.average_price}"
  puts "  Current Value: ₹#{holding.current_value}"
end
```

### Funds

#### Get Funds

```ruby
# Get account funds
funds = DhanHQ::Models::Funds.fetch
puts "Available Margin: ₹#{funds.available_margin}"
puts "Collateral: ₹#{funds.collateral}"
puts "Utilized Margin: ₹#{funds.utilized_margin}"
puts "Opening Balance: ₹#{funds.opening_balance}"
```

### Trades

#### Get Today's Trades

```ruby
# Get today's trades
trades = DhanHQ::Models::Trade.today
puts "Total trades today: #{trades.size}"

trades.each do |trade|
  puts "#{trade.trading_symbol}: #{trade.traded_qty} @ ₹#{trade.traded_price}"
end
```

#### Get Trade History

```ruby
# Get trade history
from_date = Date.today - 7
to_date = Date.today

trades = DhanHQ::Models::Trade.history(from_date: from_date, to_date: to_date)
puts "Total trades: #{trades.size}"
```

#### Find Trades by Order ID

```ruby
# Find trades for specific order
order_id = "112111182045"
trades = DhanHQ::Models::Trade.find_by_order_id(order_id)
puts "Trades for order #{order_id}: #{trades.size}"

trades.each do |trade|
  puts "  Trade ID: #{trade.trade_id}"
  puts "  Quantity: #{trade.traded_qty}"
  puts "  Price: ₹#{trade.traded_price}"
end
```

### Profile

#### Get Profile

```ruby
# Get user profile
profile = DhanHQ::Models::Profile.fetch
puts "Name: #{profile.name}"
puts "Email: #{profile.email}"
puts "Mobile: #{profile.mobile}"
puts "PAN: #{profile.pan}"
puts "Client ID: #{profile.dhan_client_id}"
```

### Market Feed

#### Get LTP (Last Traded Price)

```ruby
# Get LTP for multiple instruments
payload = {
  "NSE_EQ" => [11536, 3456],  # TCS, RELIANCE
  "NSE_FNO" => [49081, 49082]
}

response = DhanHQ::Models::MarketFeed.ltp(payload)
puts "LTP Data:"
response[:data].each do |segment, instruments|
  instruments.each do |security_id, data|
    puts "  #{segment}:#{security_id} = ₹#{data[:last_price]}"
  end
end
```

#### Get OHLC Data

```ruby
# Get OHLC for instruments
payload = {
  "NSE_EQ" => [11536]
}

response = DhanHQ::Models::MarketFeed.ohlc(payload)
tcs_data = response[:data]["NSE_EQ"]["11536"]
puts "TCS OHLC:"
puts "  Open: ₹#{tcs_data[:ohlc][:open]}"
puts "  High: ₹#{tcs_data[:ohlc][:high]}"
puts "  Low: ₹#{tcs_data[:ohlc][:low]}"
puts "  Close: ₹#{tcs_data[:ohlc][:close]}"
```

#### Get Quote (Full Market Depth)

```ruby
# Get full quote
payload = {
  "NSE_FNO" => [49081]
}

response = DhanHQ::Models::MarketFeed.quote(payload)
quote_data = response[:data]["NSE_FNO"]["49081"]
puts "Quote Data:"
puts "  LTP: ₹#{quote_data[:ltp]}"
puts "  Volume: #{quote_data[:volume]}"
puts "  Open Interest: #{quote_data[:oi]}"
puts "  Bid Price: ₹#{quote_data[:bid_price]}"
puts "  Ask Price: ₹#{quote_data[:ask_price]}"
```

### Historical Data

#### Get Daily Historical Data

```ruby
# Get daily candles
historical_data = DhanHQ::Models::HistoricalData.daily(
  security_id: "11536",
  exchange_segment: "NSE_EQ",
  from_date: Date.today - 30,
  to_date: Date.today
)

puts "Total candles: #{historical_data.size}"
historical_data.first(5).each do |candle|
  puts "#{candle[:date]}: O=₹#{candle[:open]}, H=₹#{candle[:high]}, L=₹#{candle[:low]}, C=₹#{candle[:close]}"
end
```

#### Get Intraday Historical Data

```ruby
# Get intraday candles (5-minute interval)
historical_data = DhanHQ::Models::HistoricalData.intraday(
  security_id: "11536",
  exchange_segment: "NSE_EQ",
  from_date: Date.today,
  to_date: Date.today,
  interval: 5
)

puts "Total candles: #{historical_data.size}"
historical_data.first(5).each do |candle|
  puts "#{candle[:time]}: O=₹#{candle[:open]}, H=₹#{candle[:high]}, L=₹#{candle[:low]}, C=₹#{candle[:close]}"
end
```

### Option Chain

#### Get Expiry List

```ruby
# Get expiry list for NIFTY
expiry_list = DhanHQ::Models::OptionChain.fetch_expiry_list(
  underlying_scrip: "NIFTY",
  underlying_seg: "IDX_I"
)

puts "Available expiries:"
expiry_list.each do |expiry|
  puts "  #{expiry[:expiry_date]}"
end
```

#### Get Option Chain

```ruby
# Get option chain for NIFTY
expiry_date = expiry_list.first[:expiry_date]  # Use first expiry from above

option_chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: "NIFTY",
  underlying_seg: "IDX_I",
  expiry: expiry_date
)

puts "Option Chain for #{expiry_date}:"
puts "Total strikes: #{option_chain.size}"

# Display first few strikes
option_chain.first(5).each do |strike|
  puts "  Strike: #{strike[:strike_price]}"
  puts "    CE: #{strike[:call_option]&.dig(:trading_symbol)}"
  puts "    PE: #{strike[:put_option]&.dig(:trading_symbol)}"
end
```

### Instruments

#### Find Instrument

```ruby
# Find instrument by symbol
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")
if tcs
  puts "Found: #{tcs.symbol_name}"
  puts "Security ID: #{tcs.security_id}"
  puts "Exchange Segment: #{tcs.exchange_segment}"
  puts "Instrument Type: #{tcs.instrument}"
end
```

#### Find Instrument Anywhere

```ruby
# Search across all exchanges
reliance = DhanHQ::Models::Instrument.find_anywhere("RELIANCE")
if reliance
  puts "Found: #{reliance.symbol_name}"
  puts "Exchange: #{reliance.exchange_segment}"
  puts "Security ID: #{reliance.security_id}"
end
```

#### Use Instrument Helper Methods

```ruby
# Get instrument
instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

# Use convenience methods
if instrument
  # Get LTP
  ltp_data = instrument.ltp
  puts "LTP: ₹#{ltp_data[:last_price]}"
  
  # Get OHLC
  ohlc_data = instrument.ohlc
  puts "OHLC: #{ohlc_data[:ohlc]}"
  
  # Get Quote
  quote_data = instrument.quote
  puts "Quote: #{quote_data[:ltp]}"
  
  # Get Daily Historical Data
  daily_data = instrument.daily(
    from_date: Date.today - 7,
    to_date: Date.today
  )
  puts "Daily candles: #{daily_data.size}"
  
  # Get Intraday Historical Data
  intraday_data = instrument.intraday(
    from_date: Date.today,
    to_date: Date.today,
    interval: 5
  )
  puts "Intraday candles: #{intraday_data.size}"
  
  # Get Expiry List (for F&O instruments)
  if instrument.instrument == "FUTSTK" || instrument.instrument == "OPTSTK"
    expiry_list = instrument.expiry_list
    puts "Expiries: #{expiry_list.size}"
  end
end
```

### Super Orders

#### Get All Super Orders

```ruby
# Get all super orders
super_orders = DhanHQ::Models::SuperOrder.all
puts "Total super orders: #{super_orders.size}"
```

#### Create Super Order

```ruby
# Create a multi-leg super order
super_order = DhanHQ::Models::SuperOrder.create(
  dhan_client_id: "1000000003",
  legs: [
    {
      leg_name: "ENTRY_LEG",
      transaction_type: "BUY",
      exchange_segment: "NSE_FNO",
      product_type: "MARGIN",
      order_type: "LIMIT",
      validity: "DAY",
      security_id: "49081",
      quantity: 50,
      price: 18000.0
    },
    {
      leg_name: "EXIT_LEG",
      transaction_type: "SELL",
      exchange_segment: "NSE_FNO",
      product_type: "MARGIN",
      order_type: "LIMIT",
      validity: "DAY",
      security_id: "49081",
      quantity: 50,
      price: 18100.0
    }
  ]
)

puts "Super Order ID: #{super_order.super_order_id}"
```

#### Cancel Super Order

```ruby
# Find super order
super_order = DhanHQ::Models::SuperOrder.all.first

# Cancel specific leg
if super_order
  if super_order.cancel("ENTRY_LEG")
    puts "Leg cancelled successfully"
  end
end
```

### Forever Orders (GTT)

#### Get All Forever Orders

```ruby
# Get all forever orders (GTT)
forever_orders = DhanHQ::Models::ForeverOrder.all
puts "Total forever orders: #{forever_orders.size}"
```

#### Create Forever Order

```ruby
# Create a forever order (GTT)
forever_order = DhanHQ::Models::ForeverOrder.create(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "MARGIN",
  order_type: "LIMIT",
  validity: "GTC",
  security_id: "11536",
  quantity: 1,
  price: 3500.0,
  trigger_price: 3450.0,
  condition: "LTP_LESS_THAN_OR_EQUAL"
)

puts "Forever Order ID: #{forever_order.order_id}"
```

#### Cancel Forever Order

```ruby
# Find forever order
forever_order = DhanHQ::Models::ForeverOrder.all.first

# Cancel forever order
if forever_order
  if forever_order.cancel
    puts "Forever order cancelled successfully"
  end
end
```

### EDIS

#### Get EDIS Form

```ruby
# Get EDIS form
edis_form = DhanHQ::Models::Edis.form
puts "EDIS Form:"
puts "  ISIN: #{edis_form[:isin]}"
puts "  Quantity: #{edis_form[:quantity]}"
```

#### Get Bulk EDIS Form

```ruby
# Get bulk EDIS form
bulk_form = DhanHQ::Models::Edis.bulk_form
puts "Bulk Form: #{bulk_form.size} entries"
```

#### Generate TPIN

```ruby
# Generate TPIN
tpin = DhanHQ::Models::Edis.generate_tpin
puts "TPIN: #{tpin[:tpin]}"
```

#### Inquire EDIS Status

```ruby
# Inquire EDIS status by ISIN
isin = "INE467B01029"  # Example ISIN
status = DhanHQ::Models::Edis.inquire(isin: isin)
puts "EDIS Status: #{status[:status]}"
```

### Kill Switch

#### Activate Kill Switch

```ruby
# Activate kill switch
result = DhanHQ::Models::KillSwitch.update(status: "ACTIVATE")
if result
  puts "Kill switch activated"
else
  puts "Failed to activate kill switch"
end
```

#### Deactivate Kill Switch

```ruby
# Deactivate kill switch
result = DhanHQ::Models::KillSwitch.update(status: "DEACTIVATE")
if result
  puts "Kill switch deactivated"
else
  puts "Failed to deactivate kill switch"
end
```

### Expired Options Data

#### Fetch Expired Options Data

```ruby
# Fetch expired options data
expired_data = DhanHQ::Models::ExpiredOptionsData.fetch(
  security_id: 12345,
  expiry_code: "20240125",
  strike: 18000,
  interval: "5",
  required_data: ["ohlc", "volume"]
)

puts "Expired Options Data:"
puts "  Total records: #{expired_data.size}"
expired_data.first(5).each do |record|
  puts "  #{record[:time]}: O=₹#{record[:open]}, H=₹#{record[:high]}, L=₹#{record[:low]}, C=₹#{record[:close]}"
end
```

### Margin Calculator

#### Calculate Margin

```ruby
# Calculate margin for an order
margin = DhanHQ::Models::Margin.calculate(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "MARGIN",
  order_type: "LIMIT",
  security_id: "11536",
  quantity: 1,
  price: 3500.0
)

puts "Margin Required: ₹#{margin.margin_required}"
puts "Available Margin: ₹#{margin.available_margin}"
puts "Utilized Margin: ₹#{margin.utilized_margin}"
```

### Ledger Entries

#### Get Ledger Entries

```ruby
# Get ledger entries
from_date = Date.today - 7
to_date = Date.today

ledger_entries = DhanHQ::Models::LedgerEntry.all(
  from_date: from_date,
  to_date: to_date
)

puts "Total ledger entries: #{ledger_entries.size}"
ledger_entries.first(10).each do |entry|
  puts "#{entry[:date]}: #{entry[:description]} - ₹#{entry[:amount]}"
end
```

---

## Validation Contracts Testing

### Place Order Contract

```ruby
# Test valid order
valid_params = {
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "INTRADAY",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "11536",
  quantity: 1,
  price: 3500.0
}

contract = DhanHQ::Contracts::PlaceOrderContract.new
result = contract.call(valid_params)
if result.success?
  puts "Validation passed"
else
  puts "Validation errors: #{result.errors.to_h}"
end

# Test invalid order (missing required field)
invalid_params = {
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ"
  # Missing required fields
}

result = contract.call(invalid_params)
if result.failure?
  puts "Validation failed as expected"
  puts "Errors: #{result.errors.to_h}"
end

# Test invalid price (NaN)
invalid_price_params = valid_params.merge(price: Float::NAN)
result = contract.call(invalid_price_params)
if result.failure?
  puts "NaN validation caught: #{result.errors.to_h}"
end

# Test invalid price (Infinity)
invalid_inf_params = valid_params.merge(price: Float::INFINITY)
result = contract.call(invalid_inf_params)
if result.failure?
  puts "Infinity validation caught: #{result.errors.to_h}"
end

# Test price exceeding upper bound
invalid_upper_params = valid_params.merge(price: 2_000_000_000)
result = contract.call(invalid_upper_params)
if result.failure?
  puts "Upper bound validation caught: #{result.errors.to_h}"
end
```

### Modify Order Contract

```ruby
# Test valid modification
valid_params = {
  dhan_client_id: "1000000003",
  order_id: "112111182045",
  price: 3501.0,
  quantity: 2
}

contract = DhanHQ::Contracts::ModifyOrderContract.new
result = contract.call(valid_params)
if result.success?
  puts "Validation passed"
else
  puts "Validation errors: #{result.errors.to_h}"
end
```

### Margin Calculator Contract

```ruby
# Test valid margin calculation
valid_params = {
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "MARGIN",
  order_type: "LIMIT",
  security_id: "11536",
  quantity: 1,
  price: 3500.0
}

contract = DhanHQ::Contracts::MarginCalculatorContract.new
result = contract.call(valid_params)
if result.success?
  puts "Validation passed"
else
  puts "Validation errors: #{result.errors.to_h}"
end
```

### Option Chain Contract

```ruby
# Test valid option chain request
valid_params = {
  underlying_scrip: "NIFTY",
  underlying_seg: "IDX_I",
  expiry: "2024-01-25"
}

contract = DhanHQ::Contracts::OptionChainContract.new
result = contract.call(valid_params)
if result.success?
  puts "Validation passed"
else
  puts "Validation errors: #{result.errors.to_h}"
end

# Test invalid expiry format
invalid_params = valid_params.merge(expiry: "25-01-2024")
result = contract.call(invalid_params)
if result.failure?
  puts "Invalid expiry format caught: #{result.errors.to_h}"
end
```

### Historical Data Contract

```ruby
# Test valid historical data request
valid_params = {
  security_id: "11536",
  exchange_segment: "NSE_EQ",
  from_date: Date.today - 7,
  to_date: Date.today,
  interval: 5
}

contract = DhanHQ::Contracts::HistoricalDataContract.new
result = contract.call(valid_params)
if result.success?
  puts "Validation passed"
else
  puts "Validation errors: #{result.errors.to_h}"
end

# Test date range validation (max 31 days)
invalid_params = valid_params.merge(
  from_date: Date.today - 35,
  to_date: Date.today
)
result = contract.call(invalid_params)
if result.failure?
  puts "Date range validation caught: #{result.errors.to_h}"
end
```

---

## Error Handling Testing

### Test Rate Limit Error

```ruby
# Make rapid requests to trigger rate limit
10.times do |i|
  begin
    DhanHQ::Models::Funds.fetch
    puts "Request #{i + 1} succeeded"
  rescue DhanHQ::RateLimitError => e
    puts "Rate limit error: #{e.message}"
    break
  end
  sleep(0.1)
end
```

### Test Authentication Error

```ruby
# Temporarily remove access token
original_token = DhanHQ.configuration.access_token
DhanHQ.configuration.access_token = nil

begin
  DhanHQ::Models::Funds.fetch
rescue DhanHQ::InvalidAuthenticationError => e
  puts "Authentication error caught: #{e.message}"
ensure
  # Restore token
  DhanHQ.configuration.access_token = original_token
end
```

### Test Validation Error

```ruby
# Try to place order with invalid data
begin
  order = DhanHQ::Models::Order.place(
    transaction_type: "INVALID_TYPE",
    exchange_segment: "NSE_EQ"
  )
rescue DhanHQ::Error => e
  puts "Validation error caught: #{e.message}"
end
```

### Test Network Error Handling

```ruby
# Test retry logic (will retry on transient errors)
begin
  # This will use retry logic for transient errors
  funds = DhanHQ::Models::Funds.fetch
  puts "Success: #{funds.available_margin}"
rescue DhanHQ::NetworkError => e
  puts "Network error after retries: #{e.message}"
end
```

---

## Rate Limiting Testing

### Test Rate Limiter

```ruby
# Check rate limiter status
rate_limiter = DhanHQ::Client.new(api_type: :trading).instance_variable_get(:@rate_limiter)

# Make multiple requests and observe throttling
start_time = Time.now
5.times do |i|
  rate_limiter.throttle!
  puts "Request #{i + 1} at #{Time.now - start_time}s"
end

# Shutdown rate limiter (cleanup)
rate_limiter.shutdown
```

### Test Rate Limit Per Second

```ruby
# Test per-second rate limiting
start_time = Time.now
10.times do |i|
  begin
    DhanHQ::Models::Funds.fetch
    elapsed = Time.now - start_time
    puts "Request #{i + 1} completed at #{elapsed.round(2)}s"
  rescue DhanHQ::RateLimitError => e
    puts "Rate limited at request #{i + 1}: #{e.message}"
  end
  sleep(0.1)
end
```

---

## Advanced Testing Scenarios

### End-to-End Order Flow

```ruby
# Complete order lifecycle test
puts "=== Order Lifecycle Test ==="

# 1. Check funds
funds = DhanHQ::Models::Funds.fetch
puts "1. Available Margin: ₹#{funds.available_margin}"

# 2. Calculate margin
margin = DhanHQ::Models::Margin.calculate(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "MARGIN",
  order_type: "LIMIT",
  security_id: "11536",
  quantity: 1,
  price: 3500.0
)
puts "2. Margin Required: ₹#{margin.margin_required}"

# 3. Place order
order = DhanHQ::Models::Order.place(
  dhan_client_id: "1000000003",
  transaction_type: "BUY",
  exchange_segment: "NSE_EQ",
  product_type: "MARGIN",
  order_type: "LIMIT",
  validity: "DAY",
  security_id: "11536",
  quantity: 1,
  price: 3500.0
)
puts "3. Order Placed: #{order.order_id}, Status: #{order.order_status}"

# 4. Monitor order via WebSocket
orders_client = DhanHQ::WS::Orders.client
orders_client.on(:update) do |update|
  if update.order_no == order.order_id
    puts "4. Order Update: #{update.status}"
  end
end
orders_client.start

# 5. Modify order (if pending)
sleep(2)
order.refresh
if order.order_status == "PENDING"
  if order.modify(price: 3501.0)
    puts "5. Order Modified"
  end
end

# 6. Cancel order
sleep(2)
if order.cancel
  puts "6. Order Cancelled"
end

# 7. Check trades
trades = DhanHQ::Models::Trade.find_by_order_id(order.order_id)
puts "7. Trades: #{trades.size}"

# Cleanup
orders_client.stop
puts "=== Test Complete ==="
```

### Market Data Analysis

```ruby
# Get historical data and analyze
historical_data = DhanHQ::Models::HistoricalData.daily(
  security_id: "11536",
  exchange_segment: "NSE_EQ",
  from_date: Date.today - 30,
  to_date: Date.today
)

# Calculate simple moving average
prices = historical_data.map { |c| c[:close] }
sma_20 = prices.last(20).sum / 20.0
puts "20-day SMA: ₹#{sma_20.round(2)}"

# Get current LTP
ltp_data = DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => [11536])
current_price = ltp_data[:data]["NSE_EQ"]["11536"][:last_price]
puts "Current Price: ₹#{current_price}"

# Compare
if current_price > sma_20
  puts "Price is above 20-day SMA"
else
  puts "Price is below 20-day SMA"
end
```

### Option Strategy Testing

```ruby
# Get option chain
expiry_list = DhanHQ::Models::OptionChain.fetch_expiry_list(
  underlying_scrip: "NIFTY",
  underlying_seg: "IDX_I"
)

expiry = expiry_list.first[:expiry_date]
option_chain = DhanHQ::Models::OptionChain.fetch(
  underlying_scrip: "NIFTY",
  underlying_seg: "IDX_I",
  expiry: expiry
)

# Find ATM strike
ltp_data = DhanHQ::Models::MarketFeed.ltp("IDX_I" => [13])
nifty_ltp = ltp_data[:data]["IDX_I"]["13"][:last_price]
atm_strike = (nifty_ltp / 50).round * 50

# Find ATM options
atm_option = option_chain.find { |o| o[:strike_price] == atm_strike }
if atm_option
  puts "ATM Strike: #{atm_strike}"
  puts "CE Symbol: #{atm_option[:call_option]&.dig(:trading_symbol)}"
  puts "PE Symbol: #{atm_option[:put_option]&.dig(:trading_symbol)}"
end
```

---

## Tips for Console Testing

1. **Use Variables**: Store results in variables for reuse
   ```ruby
   order = DhanHQ::Models::Order.find("112111182045")
   order.modify(price: 3501.0)
   ```

2. **Use Helper Methods**: Leverage instrument helper methods
   ```ruby
   instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")
   ltp = instrument.ltp
   ```

3. **Monitor WebSockets**: Keep WebSocket clients running in background
   ```ruby
   orders_client = DhanHQ::WS::Orders.client
   orders_client.start
   # Continue working, updates will print automatically
   ```

4. **Error Handling**: Wrap risky operations in begin/rescue
   ```ruby
   begin
     order = DhanHQ::Models::Order.place(params)
   rescue DhanHQ::Error => e
     puts "Error: #{e.message}"
   end
   ```

5. **Cleanup**: Always stop WebSocket connections when done
   ```ruby
   orders_client.stop
   market_client.stop
   ```

---

## Quick Reference

### Common Exchange Segments
- `NSE_EQ` - NSE Equity
- `BSE_EQ` - BSE Equity
- `NSE_FNO` - NSE F&O
- `BSE_FNO` - BSE F&O
- `IDX_I` - Indices (NIFTY, BANKNIFTY, etc.)

### Common Product Types
- `INTRADAY` - Intraday
- `MARGIN` - Margin
- `CNC` - Cash and Carry
- `CO` - Cover Order
- `BO` - Bracket Order

### Common Order Types
- `MARKET` - Market Order
- `LIMIT` - Limit Order
- `STOPLOSS` - Stop Loss Order
- `STOPLOSS_MARKET` - Stop Loss Market Order

### Common Transaction Types
- `BUY` - Buy
- `SELL` - Sell

---

This guide provides comprehensive examples for testing all features of the DhanHQ client gem. Use these examples in `bin/console` to explore and test the gem's functionality.
