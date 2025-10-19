# WebSocket Integration Guide

This guide covers the comprehensive WebSocket integration provided by the DhanHQ Ruby client gem. The gem provides three types of WebSocket connections for real-time data streaming with improved architecture, security, and reliability.

## Overview

The DhanHQ WebSocket integration provides three distinct WebSocket types:

1. **Market Feed WebSocket** - Live market data for indices and stocks
2. **Order Update WebSocket** - Real-time order updates and status changes
3. **Market Depth WebSocket** - Real-time market depth (bid/ask levels)

### Key Features

- **🔒 Secure Logging** - Sensitive information (access tokens) are automatically sanitized from logs
- **⚡ Rate Limit Protection** - Built-in protection against 429 errors with proper connection management
- **🔄 Automatic Reconnection** - Exponential backoff with 60-second cool-off periods
- **🧵 Thread-Safe Operation** - Safe for Rails applications and multi-threaded environments
- **📊 Comprehensive Examples** - Ready-to-use examples for all WebSocket types
- **🛡️ Error Handling** - Robust error handling and connection management

## Quick Start

### 1. Configuration

```ruby
require 'dhan_hq'

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end
```

### 2. Market Feed WebSocket (Recommended for Beginners)

```ruby
# Subscribe to major Indian indices
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
end

# Subscribe to specific indices
market_client.subscribe_one(segment: "IDX_I", security_id: "13")  # NIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "25")  # BANKNIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "29")  # NIFTYIT
market_client.subscribe_one(segment: "IDX_I", security_id: "51")  # SENSEX

# Clean shutdown
market_client.stop
```

### 3. Order Update WebSocket

```ruby
# Real-time order updates
orders_client = DhanHQ::WS::Orders.connect do |order_update|
  puts "Order Update: #{order_update.order_no} - #{order_update.status}"
  puts "  Symbol: #{order_update.symbol}"
  puts "  Quantity: #{order_update.quantity}"
  puts "  Traded Qty: #{order_update.traded_qty}"
  puts "  Price: #{order_update.price}"
  puts "  Execution: #{order_update.execution_percentage}%"
end

# Clean shutdown
orders_client.stop
```

### 4. Market Depth WebSocket

```ruby
# Real-time market depth for stocks (using dynamic symbol resolution with underlying_symbol)
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

symbols = []
if reliance
  symbols << { symbol: "RELIANCE", exchange_segment: reliance.exchange_segment, security_id: reliance.security_id }
end
if tcs
  symbols << { symbol: "TCS", exchange_segment: tcs.exchange_segment, security_id: tcs.security_id }
end

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
  puts "Market Depth: #{depth_data[:symbol]}"
  puts "  Best Bid: #{depth_data[:best_bid]}"
  puts "  Best Ask: #{depth_data[:best_ask]}"
  puts "  Spread: #{depth_data[:spread]}"
  puts "  Bid Levels: #{depth_data[:bids].size}"
  puts "  Ask Levels: #{depth_data[:asks].size}"
end

# Clean shutdown
depth_client.stop
```

## Detailed Usage

### Market Feed WebSocket

The Market Feed WebSocket provides real-time market data for indices and stocks.

#### Available Modes

- `:ticker` - Last traded price (LTP) updates
- `:quote` - LTP + volume + OHLC data
- `:full` - Complete market data including depth

#### Basic Usage

```ruby
# Ticker mode (recommended for most use cases)
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
end

# Quote mode (includes volume and OHLC)
market_client = DhanHQ::WS.connect(mode: :quote) do |quote|
  puts "Quote: #{quote[:segment]}:#{quote[:security_id]}"
  puts "  LTP: #{quote[:ltp]}"
  puts "  Volume: #{quote[:vol]}"
  puts "  Day High: #{quote[:day_high]}"
  puts "  Day Low: #{quote[:day_low]}"
end
```

#### Subscription Management

```ruby
client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts tick[:ltp] }

# Subscribe to individual instruments
client.subscribe_one(segment: "IDX_I", security_id: "13")   # NIFTY
client.subscribe_one(segment: "IDX_I", security_id: "25")   # BANKNIFTY
client.subscribe_one(segment: "NSE_EQ", security_id: "2885") # RELIANCE

# Subscribe to multiple instruments
instruments = [
  { ExchangeSegment: "IDX_I", SecurityId: "13" },
  { ExchangeSegment: "IDX_I", SecurityId: "25" },
  { ExchangeSegment: "NSE_EQ", SecurityId: "2885" }
]
client.subscribe_many(instruments)

# Unsubscribe
client.unsubscribe_one(segment: "IDX_I", security_id: "13")
```

#### Finding Correct Security IDs

```ruby
# Method 1: Using the new .find method (recommended)
# For equity instruments, uses underlying_symbol (e.g., "RELIANCE" instead of "RELIANCE INDUSTRIES LTD")
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")
nifty = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")

puts "RELIANCE Security ID: #{reliance.security_id}"  # 2885
puts "TCS Security ID: #{tcs.security_id}"          # 11536
puts "NIFTY Security ID: #{nifty.security_id}"       # 13

# Method 2: Using .find_anywhere for cross-segment search
reliance_anywhere = DhanHQ::Models::Instrument.find_anywhere("RELIANCE")
puts "RELIANCE found in: #{reliance_anywhere.exchange_segment}:#{reliance_anywhere.security_id}"

# Method 3: Manual search (legacy)
nse_instruments = DhanHQ::Models::Instrument.by_segment("NSE_EQ")
idx_instruments = DhanHQ::Models::Instrument.by_segment("IDX_I")

reliance_manual = nse_instruments.select { |i| i.symbol_name == "RELIANCE INDUSTRIES LTD" }
nifty_manual = idx_instruments.select { |i| i.symbol_name == "NIFTY" }

puts "RELIANCE Security ID: #{reliance_manual.first.security_id}"  # 2885
puts "NIFTY Security ID: #{nifty_manual.first.security_id}"       # 13
```

#### Advanced Symbol Search Options

```ruby
# Exact match search
reliance_exact = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE INDUSTRIES LTD", exact_match: true)

# Case sensitive search
reliance_case = DhanHQ::Models::Instrument.find("NSE_EQ", "reliance industries ltd", case_sensitive: true)

# Search across specific segments only
reliance_limited = DhanHQ::Models::Instrument.find_anywhere("RELIANCE", segments: ["NSE_EQ", "BSE_EQ"])

# Find multiple instruments
symbols = ["RELIANCE INDUSTRIES LTD", "TATA CONSULTANCY SERV LT", "NIFTY", "BANKNIFTY"]
instruments = symbols.map do |symbol|
  DhanHQ::Models::Instrument.find_anywhere(symbol, exact_match: true)
end.compact
```

### Order Update WebSocket

The Order Update WebSocket provides real-time updates for all orders placed through your account.

#### Basic Usage

```ruby
# Simple connection
orders_client = DhanHQ::WS::Orders.connect do |order_update|
  puts "Order Update: #{order_update.order_no} - #{order_update.status}"
  puts "  Symbol: #{order_update.symbol}"
  puts "  Quantity: #{order_update.quantity}"
  puts "  Traded Qty: #{order_update.traded_qty}"
  puts "  Price: #{order_update.price}"
  puts "  Execution: #{order_update.execution_percentage}%"
end
```

#### Advanced Event Handling

```ruby
client = DhanHQ::WS::Orders.client

# Multiple event handlers
client.on(:update) do |order_update|
  puts "📝 Order Updated: #{order_update.order_no}"
end

client.on(:status_change) do |change_data|
  puts "🔄 Status Changed: #{change_data[:previous_status]} -> #{change_data[:new_status]}"
end

client.on(:execution) do |execution_data|
  puts "✅ Execution: #{execution_data[:new_traded_qty]} shares executed"
end

client.on(:order_traded) do |order_update|
  puts "💰 Order Traded: #{order_update.order_no} - #{order_update.symbol}"
end

client.on(:order_rejected) do |order_update|
  puts "❌ Order Rejected: #{order_update.order_no} - #{order_update.reason_description}"
end

client.on(:error) do |error|
  puts "⚠️  WebSocket Error: #{error}"
end

client.on(:close) do |close_info|
  puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
end

client.start
```

#### Available Events

- `:update` - Any order update
- `:status_change` - Order status changed
- `:execution` - Order execution update
- `:order_traded` - Order traded
- `:order_rejected` - Order rejected
- `:order_cancelled` - Order cancelled
- `:order_expired` - Order expired
- `:open` - Connection opened
- `:close` - Connection closed
- `:error` - Connection error

### Market Depth WebSocket

The Market Depth WebSocket provides real-time market depth data including bid/ask levels.

#### Basic Usage

```ruby
# Method 1: Using the new .find method (recommended)
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

symbols = []
if reliance
  symbols << { symbol: "RELIANCE", exchange_segment: reliance.exchange_segment, security_id: reliance.security_id }
end
if tcs
  symbols << { symbol: "TCS", exchange_segment: tcs.exchange_segment, security_id: tcs.security_id }
end

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
  puts "Market Depth: #{depth_data[:symbol]}"
  puts "  Best Bid: #{depth_data[:best_bid]}"
  puts "  Best Ask: #{depth_data[:best_ask]}"
  puts "  Spread: #{depth_data[:spread]}"
  puts "  Bid Levels: #{depth_data[:bids].size}"
  puts "  Ask Levels: #{depth_data[:asks].size}"
end

# Method 2: Direct specification (legacy)
symbols_direct = [
  { symbol: "RELIANCE", exchange_segment: "NSE_EQ", security_id: "2885" },
  { symbol: "TCS", exchange_segment: "NSE_EQ", security_id: "11536" }
]

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols_direct) do |depth_data|
  puts "Market Depth: #{depth_data[:symbol]}"
  puts "  Best Bid: #{depth_data[:best_bid]}"
  puts "  Best Ask: #{depth_data[:best_ask]}"
  puts "  Spread: #{depth_data[:spread]}"
  puts "  Bid Levels: #{depth_data[:bids].size}"
  puts "  Ask Levels: #{depth_data[:asks].size}"
end
```

#### Advanced Usage

```ruby
client = DhanHQ::WS::MarketDepth.client

# Event handlers
client.on(:depth_update) do |update_data|
  puts "📊 Depth Update: #{update_data[:symbol]} - #{update_data[:side]} side updated"
end

client.on(:depth_snapshot) do |snapshot_data|
  puts "📸 Depth Snapshot: #{snapshot_data[:symbol]} - Full order book received"
end

client.on(:error) do |error|
  puts "⚠️  WebSocket Error: #{error}"
end

client.start

# Subscribe to symbols
symbols = [
  { symbol: "RELIANCE", exchange_segment: "NSE_EQ", security_id: "2885" },
  { symbol: "TCS", exchange_segment: "NSE_EQ", security_id: "11536" }
]
client.subscribe(symbols)
```

#### Finding Correct Symbols

```ruby
# Method 1: Using the new .find method (recommended)
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

puts "RELIANCE: #{reliance.exchange_segment}:#{reliance.security_id}"  # NSE:2885
puts "TCS: #{tcs.exchange_segment}:#{tcs.security_id}"                 # NSE:11536

# Method 2: Using .find_anywhere for cross-segment search
reliance_anywhere = DhanHQ::Models::Instrument.find_anywhere("RELIANCE")
tcs_anywhere = DhanHQ::Models::Instrument.find_anywhere("TCS")

puts "RELIANCE found in: #{reliance_anywhere.exchange_segment}:#{reliance_anywhere.security_id}"
puts "TCS found in: #{tcs_anywhere.exchange_segment}:#{tcs_anywhere.security_id}"

# Method 3: Manual search (legacy)
nse_instruments = DhanHQ::Models::Instrument.by_segment("NSE_EQ")

reliance_manual = nse_instruments.select { |i| i.underlying_symbol == "RELIANCE" }
tcs_manual = nse_instruments.select { |i| i.underlying_symbol == "TCS" }

puts "RELIANCE: NSE_EQ:#{reliance_manual.first.security_id}"  # NSE_EQ:2885
puts "TCS: NSE_EQ:#{tcs_manual.first.security_id}"           # NSE_EQ:11536
```

## Instrument Model with Trading Fields

The DhanHQ Instrument model now includes comprehensive trading fields essential for order validation, risk management, and compliance monitoring.

### Available Trading Fields

```ruby
# Find an instrument with all trading fields
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")

# Core identification fields
puts "Symbol: #{reliance.symbol_name}"                    # RELIANCE INDUSTRIES LTD
puts "Underlying Symbol: #{reliance.underlying_symbol}"  # RELIANCE
puts "Security ID: #{reliance.security_id}"              # 2885
puts "ISIN: #{reliance.isin}"                            # INE002A01018
puts "Instrument Type: #{reliance.instrument_type}"      # ES

# Trading permission and restrictions
puts "Buy/Sell Indicator: #{reliance.buy_sell_indicator}" # A (Allowed)
puts "Bracket Flag: #{reliance.bracket_flag}"            # N (Not Allowed)
puts "Cover Flag: #{reliance.cover_flag}"                # N (Not Allowed)
puts "ASM/GSM Flag: #{reliance.asm_gsm_flag}"           # N (No Restrictions)
puts "ASM/GSM Category: #{reliance.asm_gsm_category}"    # NA

# Margin and leverage information
puts "Buy CO Min Margin %: #{reliance.buy_co_min_margin_per}"   # 0.0
puts "Sell CO Min Margin %: #{reliance.sell_co_min_margin_per}" # 0.0
puts "MTF Leverage: #{reliance.mtf_leverage}"                  # 4.545455

# Expiry information
puts "Expiry Flag: #{reliance.expiry_flag}"              # NA (No Expiry)
puts "Expiry Date: #{reliance.expiry_date}"              # nil
```

### Trading Field Usage Examples

#### Order Validation
```ruby
def validate_order(instrument, order_type)
  # Check if trading is allowed
  return false unless instrument.buy_sell_indicator == "A"

  # Check order type support
  case order_type
  when :bracket
    return false unless instrument.bracket_flag == "Y"
  when :cover
    return false unless instrument.cover_flag == "Y"
  end

  # Check ASM/GSM restrictions
  if instrument.asm_gsm_flag == "Y"
    puts "Warning: ASM/GSM applied - #{instrument.asm_gsm_category}"
  end

  true
end

# Usage
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
if validate_order(reliance, :bracket)
  puts "Bracket order allowed for RELIANCE"
else
  puts "Bracket order not allowed for RELIANCE"
end
```

#### Margin Calculations
```ruby
def calculate_margin(instrument, quantity, price)
  total_value = quantity * price * instrument.lot_size

  # Calculate margin requirements
  buy_margin = total_value * (instrument.buy_co_min_margin_per / 100.0)
  sell_margin = total_value * (instrument.sell_co_min_margin_per / 100.0)

  # Calculate MTF leverage
  mtf_value = instrument.mtf_leverage > 0 ? total_value * instrument.mtf_leverage : 0

  {
    total_value: total_value,
    buy_margin: buy_margin,
    sell_margin: sell_margin,
    mtf_value: mtf_value,
    mtf_leverage: instrument.mtf_leverage
  }
end

# Usage
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
margin_info = calculate_margin(reliance, 10, 2500)
puts "Total Value: ₹#{margin_info[:total_value]}"
puts "MTF Leverage: #{margin_info[:mtf_leverage]}x"
puts "MTF Value: ₹#{margin_info[:mtf_value]}"
```

#### Risk Management
```ruby
def assess_risk(instrument)
  risk_factors = []

  # Check ASM/GSM status
  if instrument.asm_gsm_flag == "Y"
    risk_factors << "ASM/GSM Applied: #{instrument.asm_gsm_category}"
  end

  # Check expiry
  if instrument.expiry_flag == "Y"
    risk_factors << "Instrument has expiry: #{instrument.expiry_date}"
  end

  # Check high leverage
  if instrument.mtf_leverage > 5.0
    risk_factors << "High MTF leverage: #{instrument.mtf_leverage}x"
  end

  risk_factors
end

# Usage
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
risks = assess_risk(reliance)
if risks.any?
  puts "Risk factors:"
  risks.each { |risk| puts "  - #{risk}" }
else
  puts "No significant risk factors identified"
end
```

### Trading Fields Reference

| Field                    | Type   | Description                                    | Example Values              |
| ------------------------ | ------ | ---------------------------------------------- | --------------------------- |
| `isin`                   | String | International Securities Identification Number | "INE002A01018"              |
| `instrument_type`        | String | Instrument classification                      | "ES", "INDEX", "FUT", "OPT" |
| `expiry_flag`            | String | Whether instrument has expiry                  | "Y", "N", "NA"              |
| `bracket_flag`           | String | Whether bracket orders are allowed             | "Y", "N"                    |
| `cover_flag`             | String | Whether cover orders are allowed               | "Y", "N"                    |
| `asm_gsm_flag`           | String | Additional Surveillance Measure flag           | "Y", "N"                    |
| `asm_gsm_category`       | String | ASM/GSM category classification                | "ASM", "GSM", "NA"          |
| `buy_sell_indicator`     | String | Whether instrument allows buy/sell             | "A", "N"                    |
| `buy_co_min_margin_per`  | Float  | Buy CO minimum margin percentage               | 0.0, 20.0                   |
| `sell_co_min_margin_per` | Float  | Sell CO minimum margin percentage              | 0.0, 20.0                   |
| `mtf_leverage`           | Float  | Margin Trading Facility leverage               | 0.0, 4.545455               |

## Rails Integration

### Basic Rails Integration

```ruby
# config/initializers/dhan_hq.rb
DhanHQ.configure do |config|
  config.client_id = Rails.application.credentials.dhanhq[:client_id]
  config.access_token = Rails.application.credentials.dhanhq[:access_token]
  config.ws_user_type = Rails.application.credentials.dhanhq[:ws_user_type]
end
```

### Service Class Pattern

```ruby
# app/services/market_data_service.rb
class MarketDataService
  def initialize
    @market_client = nil
  end

  def start_market_feed
    @market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
      process_market_data(tick)
    end

    # Subscribe to indices
    @market_client.subscribe_one(segment: "IDX_I", security_id: "13")  # NIFTY
    @market_client.subscribe_one(segment: "IDX_I", security_id: "25")  # BANKNIFTY
    @market_client.subscribe_one(segment: "IDX_I", security_id: "29")  # NIFTYIT
    @market_client.subscribe_one(segment: "IDX_I", security_id: "51")  # SENSEX
  end

  def stop_market_feed
    @market_client&.stop
    @market_client = nil
  end

  private

  def process_market_data(tick)
    # Store in database
    MarketData.create!(
      segment: tick[:segment],
      security_id: tick[:security_id],
      ltp: tick[:ltp],
      timestamp: tick[:ts] ? Time.at(tick[:ts]) : Time.now
    )

    # Broadcast via ActionCable
    ActionCable.server.broadcast(
      "market_data_#{tick[:segment]}",
      {
        segment: tick[:segment],
        security_id: tick[:security_id],
        ltp: tick[:ltp],
        timestamp: tick[:ts]
      }
    )
  end
end
```

### Order Update Service

```ruby
# app/services/order_update_service.rb
class OrderUpdateService
  def initialize
    @orders_client = nil
  end

  def start_order_updates
    @orders_client = DhanHQ::WS::Orders.connect do |order_update|
      process_order_update(order_update)
    end

    # Add error handling
    @orders_client.on(:error) do |error|
      Rails.logger.error "Order WebSocket error: #{error}"
    end

    @orders_client.on(:close) do |close_info|
      Rails.logger.warn "Order WebSocket closed: #{close_info[:code]}"
    end
  end

  def stop_order_updates
    @orders_client&.stop
    @orders_client = nil
  end

  private

  def process_order_update(order_update)
    # Update database
    order = Order.find_by(order_no: order_update.order_no)
    if order
      order.update!(
      status: order_update.status,
      traded_qty: order_update.traded_qty,
      avg_price: order_update.avg_traded_price
    )

      # Broadcast to user
    ActionCable.server.broadcast(
        "order_updates_#{order.user_id}",
        {
          order_no: order_update.order_no,
          status: order_update.status,
          traded_qty: order_update.traded_qty,
          execution_percentage: order_update.execution_percentage
        }
      )
    end
  end
end
```

### Background Job Processing

```ruby
# app/jobs/process_market_data_job.rb
class ProcessMarketDataJob < ApplicationJob
  queue_as :market_data

  def perform(market_data)
    # Process market data
    MarketData.create!(
      segment: market_data[:segment],
      security_id: market_data[:security_id],
      ltp: market_data[:ltp],
      volume: market_data[:vol],
      timestamp: Time.at(market_data[:ts])
    )

    # Update cache
    Rails.cache.write(
      "market_data_#{market_data[:segment]}:#{market_data[:security_id]}",
      market_data,
      expires_in: 1.minute
    )
  end
end

# In your WebSocket handler
DhanHQ::WS.connect(mode: :ticker) do |tick|
  ProcessMarketDataJob.perform_later(tick)
end
```

### Application Controller Integration

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :ensure_websocket_cleanup

  private

  def ensure_websocket_cleanup
    yield
  ensure
    # Clean up any stray WebSocket connections
    DhanHQ::WS.disconnect_all_local!
  end
end
```

## Connection Management

### Rate Limiting Protection

DhanHQ allows up to 5 WebSocket connections per user. To avoid 429 errors:

```ruby
# ✅ Good: Sequential connections
orders_client = DhanHQ::WS::Orders.connect { |order| puts order.order_no }
orders_client.stop
sleep(2)  # Wait between connections

market_client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts tick[:ltp] }
market_client.stop
sleep(2)

# ❌ Bad: Multiple simultaneous connections
orders_client = DhanHQ::WS::Orders.connect { |order| puts order.order_no }
market_client = DhanHQ::WS.connect(mode: :ticker) { |tick| puts tick[:ltp] }
depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) { |depth| puts depth[:symbol] }
```

### Graceful Shutdown

```ruby
# Disconnect all WebSocket connections
DhanHQ::WS.disconnect_all_local!

# Or disconnect individual clients
orders_client.stop
market_client.stop
depth_client.stop
```

### Connection Status Monitoring

```ruby
# Check connection status
puts "Orders connected: #{orders_client.connected?}"
puts "Market connected: #{market_client.connected?}"
puts "Depth connected: #{depth_client.connected?}"

# Get subscription info
puts "Market subscriptions: #{market_client.subscriptions}"
puts "Depth subscriptions: #{depth_client.subscriptions}"
```

## Best Practices

### 1. Security

- **✅ Sensitive information is automatically sanitized** from logs
- **✅ Use environment variables** for credentials
- **✅ Never log access tokens** or client IDs

```ruby
# ✅ Good: Environment variables
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"]
  config.access_token = ENV["ACCESS_TOKEN"]
end

# ❌ Bad: Hardcoded credentials
DhanHQ.configure do |config|
  config.client_id = "your_client_id"
  config.access_token = "your_access_token"
end
```

### 2. Error Handling

```ruby
client = DhanHQ::WS::Orders.client

client.on(:error) do |error|
  Rails.logger.error "WebSocket error: #{error}"
  # Implement retry logic or alerting
end

client.on(:close) do |close_info|
  Rails.logger.warn "WebSocket closed: #{close_info[:code]} - #{close_info[:reason]}"
  # Handle disconnection
end

client.start
```

### 3. Resource Management

```ruby
# In Rails application
class ApplicationController < ActionController::Base
  around_action :ensure_websocket_cleanup

  private

  def ensure_websocket_cleanup
    yield
  ensure
    DhanHQ::WS.disconnect_all_local!
  end
end
```

### 4. Thread Safety

All WebSocket connections are thread-safe and can be used in Rails applications:

```ruby
# Safe to use in Rails controllers, jobs, etc.
class MarketDataController < ApplicationController
  def stream
    DhanHQ::WS.connect(mode: :ticker) do |tick|
      # This is thread-safe
      Rails.logger.info "Received tick: #{tick[:symbol]}"
    end
  end
end
```

## Troubleshooting

### Common Issues

1. **429 Rate Limiting Errors**
   - Use sequential connections instead of simultaneous ones
   - Wait 2-5 seconds between connection attempts
   - The client automatically implements 60-second cool-off periods

2. **"Unable to locate instrument" Warnings**
   - Use correct exchange segments and security IDs
   - Find instruments using `DhanHQ::Models::Instrument.by_segment()`
   - Use the proper symbol format for Market Depth WebSocket

3. **Connection Failures**
   - Check credentials and network connectivity
   - Verify WebSocket URLs are correct
   - Check for firewall or proxy issues

### Debugging

Enable debug logging:

```ruby
# Set log level to debug
DhanHQ.logger.level = Logger::DEBUG

# Or use Rails logger
DhanHQ.logger = Rails.logger
```

### Monitoring

Monitor WebSocket connections:

```ruby
# Check connection status
puts "Orders connected: #{orders_client.connected?}"
puts "Market connected: #{market_client.connected?}"
puts "Depth connected: #{depth_client.connected?}"

# Get subscription info
puts "Market subscriptions: #{market_client.subscriptions}"
puts "Depth subscriptions: #{depth_client.subscriptions}"
```

## Examples

The gem includes comprehensive examples in the `examples/` directory:

- `market_feed_example.rb` - Market Feed WebSocket with major indices
- `order_update_example.rb` - Order Update WebSocket with event handling
- `market_depth_example.rb` - Market Depth WebSocket with RELIANCE and TCS
- `comprehensive_websocket_examples.rb` - All three WebSocket types

Run examples:

```bash
# Individual examples
bundle exec ruby examples/market_feed_example.rb
bundle exec ruby examples/order_update_example.rb
bundle exec ruby examples/market_depth_example.rb

# Comprehensive example
bundle exec ruby examples/comprehensive_websocket_examples.rb
```

This comprehensive WebSocket integration provides everything needed for real-time trading applications with DhanHQ, featuring improved security, reliability, and ease of use.