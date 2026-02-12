#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive WebSocket Examples
# This script demonstrates all three DhanHQ WebSocket types:
# 1. Market Feed WebSocket - Real-time market data
# 2. Order Update WebSocket - Real-time order updates
# 3. Market Depth WebSocket - Real-time market depth
# NOTE: Uses sequential connections to avoid rate limiting

require "dhan_hq"

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["DHAN_ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

puts "DhanHQ Comprehensive WebSocket Examples"
puts "======================================="
puts "Demonstrates all three WebSocket types:"
puts "1. Market Feed - Real-time market data for indices"
puts "2. Order Update - Real-time order status updates"
puts "3. Market Depth - Real-time bid/ask levels"
puts ""
puts "NOTE: Uses sequential connections to avoid rate limiting (429 errors)"
puts "Dhan allows up to 5 WebSocket connections per user"
puts ""

# Example 1: Market Feed WebSocket
puts "1. Market Feed WebSocket Example"
puts "================================"

puts "Creating Market Feed WebSocket connection..."
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
end

# Subscribe to major Indian indices
puts "\nSubscribing to major Indian indices:"
puts "- Security ID 13: NIFTY (Nifty 50)"
puts "- Security ID 25: BANKNIFTY (Nifty Bank)"
puts "- Security ID 29: NIFTYIT (Nifty IT)"
puts "- Security ID 51: SENSEX (Sensex)"

market_client.subscribe_one(segment: "IDX_I", security_id: "13")  # NIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "25")  # BANKNIFTY
market_client.subscribe_one(segment: "IDX_I", security_id: "29")  # NIFTYIT
market_client.subscribe_one(segment: "IDX_I", security_id: "51")  # SENSEX

puts "\nMarket Feed WebSocket connected successfully!"
puts "Waiting 10 seconds to receive market data..."
sleep(10)

puts "Stopping Market Feed WebSocket to prevent rate limiting..."
market_client.stop
sleep(2)

# Example 2: Order Update WebSocket
puts "\n2. Order Update WebSocket Example"
puts "=================================="

puts "Creating Order Update WebSocket connection..."
orders_client = DhanHQ::WS::Orders.connect do |order_update|
  puts "Order Update: #{order_update.order_no} - #{order_update.status}"
  puts "  Symbol: #{order_update.symbol}"
  puts "  Quantity: #{order_update.quantity}"
  puts "  Traded Qty: #{order_update.traded_qty}"
  puts "  Price: #{order_update.price}"
  puts "  Execution: #{order_update.execution_percentage}%"
  puts "  ---"
end

# Add event handlers
orders_client.on(:update) { |order| puts "📝 Order Updated: #{order.order_no}" }
orders_client.on(:execution) { |exec| puts "✅ Execution: #{exec[:new_traded_qty]} shares" }
orders_client.on(:order_rejected) { |order| puts "❌ Order Rejected: #{order.order_no}" }

puts "\nOrder Update WebSocket connected successfully!"
puts "Waiting 10 seconds to receive order updates..."
sleep(10)

puts "Stopping Order Update WebSocket to prevent rate limiting..."
orders_client.stop
sleep(2)

# Example 3: Market Depth WebSocket
puts "\n3. Market Depth WebSocket Example"
puts "=================================="

puts "Creating Market Depth WebSocket connection..."

# Find instruments using the new .find method (now uses underlying_symbol for equity)
reliance_instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs_instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")

# Define symbols with correct exchange segments and security IDs
symbols = []
if reliance_instrument
  symbols << { symbol: "RELIANCE", exchange_segment: reliance_instrument.exchange_segment,
               security_id: reliance_instrument.security_id }
  puts "✅ Found RELIANCE: #{reliance_instrument.symbol_name} (#{reliance_instrument.exchange_segment}:#{reliance_instrument.security_id})"
end

if tcs_instrument
  symbols << { symbol: "TCS", exchange_segment: tcs_instrument.exchange_segment,
               security_id: tcs_instrument.security_id }
  puts "✅ Found TCS: #{tcs_instrument.symbol_name} (#{tcs_instrument.exchange_segment}:#{tcs_instrument.security_id})"
end

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
  puts "Market Depth: #{depth_data[:symbol]}"
  puts "  Best Bid: #{depth_data[:best_bid]}"
  puts "  Best Ask: #{depth_data[:best_ask]}"
  puts "  Spread: #{depth_data[:spread]}"
  puts "  Bid Levels: #{depth_data[:bids].size}"
  puts "  Ask Levels: #{depth_data[:asks].size}"
  puts "  ---"
end

puts "\nMarket Depth WebSocket connected successfully!"
puts "Waiting 10 seconds to receive market depth data..."
sleep(10)

puts "Stopping Market Depth WebSocket to prevent rate limiting..."
depth_client.stop
sleep(2)

# Final cleanup
puts "\n4. Final Cleanup"
puts "================"

puts "Ensuring all WebSocket connections are closed..."
DhanHQ::WS.disconnect_all_local!

puts "\nAll WebSocket connections closed."
puts "Comprehensive example completed!"
puts ""
puts "Summary:"
puts "- Successfully demonstrated all three WebSocket types:"
puts "  * Market Feed: Real-time index data (NIFTY, BANKNIFTY, NIFTYIT, SENSEX)"
puts "  * Order Update: Real-time order status tracking"
puts "  * Market Depth: Real-time bid/ask levels (RELIANCE, TCS) - dynamically resolved"
puts "- Used sequential connections to avoid rate limiting (429 errors)"
puts "- Proper connection cleanup prevents resource leaks"
puts "- No multiple connection issues!"
