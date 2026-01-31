# Live Order Updates - Comprehensive Guide

The DhanHQ Ruby client provides comprehensive real-time order update functionality via WebSocket, covering all order states as per the [DhanHQ API documentation](https://dhanhq.co/docs/v2).

## Features

✅ **Complete Order State Tracking** - All order statuses (TRANSIT, PENDING, REJECTED, CANCELLED, TRADED, EXPIRED)
✅ **Real-time Execution Updates** - Track partial and full executions
✅ **Order State Management** - Query orders by status, symbol, execution state
✅ **Event-driven Architecture** - Subscribe to specific order events
✅ **Super Order Support** - Track entry, stop-loss, and target legs
✅ **Comprehensive Order Data** - All fields from API documentation

## Quick Start

### Basic Usage

```ruby
require 'dhan_hq'

# Configure credentials. For dynamic token use config.access_token_provider; for web tokens refresh with DhanHQ::Auth.renew_token. API key/Partner: implement in app. See docs/AUTHENTICATION.md.
DhanHQ.configure do |config|
  config.client_id = "your_client_id"
  config.access_token = "your_access_token"
end

# Simple order update monitoring
DhanHQ::WS::Orders.connect do |order_update|
  puts "Order Update: #{order_update.symbol} - #{order_update.status}"
  puts "Quantity: #{order_update.traded_qty}/#{order_update.quantity}"
end
```

### Advanced Usage with Event Handlers

```ruby
# Create client with multiple event handlers
client = DhanHQ::WS::Orders.connect_with_handlers({
  :update => ->(order) { puts "Order updated: #{order.order_no}" },
  :status_change => ->(data) {
    puts "Status changed: #{data[:previous_status]} -> #{data[:new_status]}"
  },
  :execution => ->(data) {
    puts "Execution: #{data[:new_traded_qty]} shares at #{data[:order_update].avg_traded_price}"
  },
  :order_traded => ->(order) { puts "Order fully executed: #{order.order_no}" },
  :order_rejected => ->(order) { puts "Order rejected: #{order.reason_description}" }
})

# Keep the connection alive
sleep
```

## Order Update Model

The `OrderUpdate` model provides comprehensive access to all order fields:

### Order Information
```ruby
order_update.order_no          # Order number
order_update.exch_order_no     # Exchange order number
order_update.symbol            # Trading symbol
order_update.display_name      # Instrument display name
order_update.security_id       # Security ID
order_update.correlation_id    # User correlation ID
```

### Order Details
```ruby
order_update.txn_type          # "B" for Buy, "S" for Sell
order_update.order_type        # "LMT", "MKT", "SL", "SLM"
order_update.product           # "C", "I", "M", "F", "V", "B"
order_update.validity          # "DAY", "IOC"
order_update.status            # "TRANSIT", "PENDING", "REJECTED", etc.
```

### Execution Information
```ruby
order_update.quantity          # Total order quantity
order_update.traded_qty         # Executed quantity
order_update.remaining_quantity # Pending quantity
order_update.price              # Order price
order_update.traded_price       # Last trade price
order_update.avg_traded_price   # Average execution price
```

### Helper Methods

#### Transaction Type
```ruby
order_update.buy?              # true if BUY order
order_update.sell?             # true if SELL order
```

#### Order Type
```ruby
order_update.limit_order?      # true if LIMIT order
order_update.market_order?     # true if MARKET order
order_update.stop_loss_order?  # true if STOP LOSS order
```

#### Product Type
```ruby
order_update.cnc_product?      # true if CNC
order_update.intraday_product? # true if INTRADAY
order_update.margin_product?   # true if MARGIN
order_update.mtf_product?      # true if MTF
order_update.cover_order?      # true if CO
order_update.bracket_order?    # true if BO
```

#### Order Status
```ruby
order_update.transit?          # true if TRANSIT
order_update.pending?           # true if PENDING
order_update.rejected?          # true if REJECTED
order_update.cancelled?         # true if CANCELLED
order_update.traded?            # true if TRADED
order_update.expired?           # true if EXPIRED
```

#### Execution State
```ruby
order_update.partially_executed? # true if partially filled
order_update.fully_executed?     # true if fully filled
order_update.not_executed?       # true if not filled
order_update.execution_percentage # execution percentage (0-100)
```

#### Super Order Legs
```ruby
order_update.entry_leg?         # true if entry leg (leg_no == 1)
order_update.stop_loss_leg?     # true if stop-loss leg (leg_no == 2)
order_update.target_leg?        # true if target leg (leg_no == 3)
order_update.super_order?        # true if part of super order
```

## Client Methods

### Order Tracking
```ruby
client = DhanHQ::WS::Orders.client.start

# Get specific order state
order = client.order_state("1124091136546")

# Get all tracked orders
all_orders = client.all_orders

# Query orders by status
pending_orders = client.orders_by_status("PENDING")
traded_orders = client.orders_by_status("TRADED")

# Query orders by symbol
reliance_orders = client.orders_by_symbol("RELIANCE")

# Query by execution state
partial_orders = client.partially_executed_orders
full_orders = client.fully_executed_orders
pending_orders = client.pending_orders
```

### Event Handling
```ruby
client = DhanHQ::WS::Orders.client

# General events
client.on(:update) { |order| puts "Order updated: #{order.order_no}" }
client.on(:raw) { |msg| puts "Raw message: #{msg}" }
client.on(:close) { puts "Connection closed" }

# Status-specific events
client.on(:order_transit) { |order| puts "Order in transit: #{order.order_no}" }
client.on(:order_pending) { |order| puts "Order pending: #{order.order_no}" }
client.on(:order_rejected) { |order| puts "Order rejected: #{order.reason_description}" }
client.on(:order_cancelled) { |order| puts "Order cancelled: #{order.order_no}" }
client.on(:order_traded) { |order| puts "Order traded: #{order.order_no}" }
client.on(:order_expired) { |order| puts "Order expired: #{order.order_no}" }

# State change events
client.on(:status_change) do |data|
  puts "Status: #{data[:previous_status]} -> #{data[:new_status]}"
end

client.on(:execution) do |data|
  puts "Execution: #{data[:new_traded_qty]} shares (#{data[:execution_percentage]}%)"
end

client.start
```

## Configuration

### Environment Variables
```bash
# Required
CLIENT_ID=your_client_id
ACCESS_TOKEN=your_access_token

# Optional WebSocket settings
DHAN_WS_ORDER_URL=wss://api-order-update.dhan.co
DHAN_WS_USER_TYPE=SELF  # or PARTNER
DHAN_PARTNER_ID=partner_id      # if UserType is PARTNER
DHAN_PARTNER_SECRET=partner_secret  # if UserType is PARTNER
```

### Programmatic Configuration
```ruby
DhanHQ.configure do |config|
  config.client_id = "your_client_id"
  config.access_token = "your_access_token"
  config.ws_order_url = "wss://api-order-update.dhan.co"
  config.ws_user_type = "SELF"  # or "PARTNER"

  # For partner mode
  config.partner_id = "partner_id"
  config.partner_secret = "partner_secret"
end
```

## Complete Example

```ruby
require 'dhan_hq'

# Configure
DhanHQ.configure_with_env

# Create order tracking client
client = DhanHQ::WS::Orders.client

# Set up comprehensive event handling
client.on(:update) do |order|
  puts "\n=== Order Update ==="
  puts "Order: #{order.order_no} | Symbol: #{order.symbol}"
  puts "Status: #{order.status} | Type: #{order.txn_type}"
  puts "Quantity: #{order.traded_qty}/#{order.quantity} (#{order.execution_percentage}%)"
  puts "Price: #{order.price} | Avg Price: #{order.avg_traded_price}"
  puts "Leg: #{order.leg_no} | Super Order: #{order.super_order?}"
end

client.on(:status_change) do |data|
  order = data[:order_update]
  puts "\n🔄 Status Change: #{order.order_no}"
  puts "   #{data[:previous_status]} -> #{data[:new_status]}"
end

client.on(:execution) do |data|
  order = data[:order_update]
  puts "\n💰 Execution Update: #{order.order_no}"
  puts "   #{data[:previous_traded_qty]} -> #{data[:new_traded_qty]} shares"
  puts "   Execution: #{data[:execution_percentage]}%"
end

client.on(:order_traded) do |order|
  puts "\n✅ Order Fully Executed: #{order.order_no}"
  puts "   Symbol: #{order.symbol} | Quantity: #{order.traded_qty}"
  puts "   Average Price: #{order.avg_traded_price}"
end

client.on(:order_rejected) do |order|
  puts "\n❌ Order Rejected: #{order.order_no}"
  puts "   Reason: #{order.reason_description}"
end

# Start monitoring
puts "Starting order update monitoring..."
client.start

# Keep running
begin
  loop do
    sleep 1

    # Print order summary every 30 seconds
    if Time.now.to_i % 30 == 0
      puts "\n📊 Order Summary:"
      puts "   Total Orders: #{client.all_orders.size}"
      puts "   Pending: #{client.orders_by_status('PENDING').size}"
      puts "   Traded: #{client.orders_by_status('TRADED').size}"
      puts "   Rejected: #{client.orders_by_status('REJECTED').size}"
    end
  end
rescue Interrupt
  puts "\nShutting down..."
  client.stop
end
```

## Order States Covered

The implementation covers all order states as per DhanHQ API documentation:

| Status      | Description                  | Event              |
| ----------- | ---------------------------- | ------------------ |
| `TRANSIT`   | Order in transit to exchange | `:order_transit`   |
| `PENDING`   | Order pending at exchange    | `:order_pending`   |
| `REJECTED`  | Order rejected by exchange   | `:order_rejected`  |
| `CANCELLED` | Order cancelled              | `:order_cancelled` |
| `TRADED`    | Order fully executed         | `:order_traded`    |
| `EXPIRED`   | Order expired                | `:order_expired`   |

## Error Handling

The WebSocket client includes comprehensive error handling:

- **Automatic Reconnection** with exponential backoff
- **Rate Limit Handling** with 60-second cool-off for 429 errors
- **Connection Monitoring** with health checks
- **Event Handler Protection** - errors in handlers don't crash the client

## Thread Safety

All operations are thread-safe using `Concurrent::Map` and `Concurrent::AtomicBoolean` for:
- Order state tracking
- Event callback management
- Connection state management

This ensures safe usage in multi-threaded applications.

## Testing

For comprehensive testing examples and interactive console helpers, see the [Testing Guide](TESTING_GUIDE.md). The guide includes:

- **Order Update WebSocket Testing**: Complete examples for all order update features
- **Event Handler Testing**: Examples for all event types
- **Order State Management**: Testing order tracking and querying
- **Interactive Console Helpers**: Load `bin/test_helpers.rb` for quick test functions

**Quick start in console:**
```ruby
# Start console
bin/console

# Load test helpers
load 'bin/test_helpers.rb'

# Test order WebSocket
test_order_websocket(10)        # Test order updates for 10 seconds

# Monitor specific order
monitor_order("112111182045")   # Monitor order by ID
```
