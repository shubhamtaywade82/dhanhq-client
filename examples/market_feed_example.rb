#!/usr/bin/env ruby
# frozen_string_literal: true

# Market Feed WebSocket Example
# This script demonstrates how to use the DhanHQ Market Feed WebSocket
# Subscribes to major Indian indices (NIFTY, BANKNIFTY, NIFTYIT, SENSEX)
# NOTE: Uses a SINGLE connection to avoid rate limiting

require "dhan_hq"

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["DHAN_ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

puts "DhanHQ Market Feed WebSocket Example"
puts "===================================="
puts "Subscribing to major Indian indices:"
puts "- NIFTY (Nifty 50)"
puts "- BANKNIFTY (Nifty Bank)"
puts "- NIFTYIT (Nifty IT)"
puts "- SENSEX (Sensex)"
puts ""
puts "NOTE: Using SINGLE connection to avoid rate limiting (429 errors)"
puts "Dhan allows up to 5 WebSocket connections per user"
puts ""

# Market Feed WebSocket Connection
puts "Market Feed WebSocket Connection"
puts "================================"

# Create a single market feed WebSocket connection
puts "Creating Market Feed WebSocket connection..."
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Market Data: #{tick[:segment]}:#{tick[:security_id]} = #{tick[:ltp]} at #{timestamp}"
end

# Subscribe to specific IDX_I instruments only
# Note: IDX_I is the correct segment for index instruments
puts "\nSubscribing to IDX_I instruments:"
puts "- Security ID 13: NIFTY (Nifty 50)"
puts "- Security ID 25: BANKNIFTY (Nifty Bank)"
puts "- Security ID 29: NIFTYIT (Nifty IT)"
puts "- Security ID 51: SENSEX (Sensex)"

market_client.subscribe_one(segment: "IDX_I", security_id: "13")  # NIFTY (Nifty 50)
market_client.subscribe_one(segment: "IDX_I", security_id: "25")  # BANKNIFTY (Nifty Bank)
market_client.subscribe_one(segment: "IDX_I", security_id: "29")  # NIFTYIT (Nifty IT)
market_client.subscribe_one(segment: "IDX_I", security_id: "51")  # SENSEX (Sensex)

puts "\nMarket Feed WebSocket connected successfully!"
puts "Waiting 15 seconds to receive market data..."
puts "Press Ctrl+C to stop early"
puts ""

# Wait for market data
begin
  sleep(15)
rescue Interrupt
  puts "\nStopping early due to user interrupt..."
end

# Graceful shutdown
puts "\nShutting down WebSocket connection..."
market_client.stop

puts "WebSocket connection closed."
puts "Example completed!"
puts ""
puts "Summary:"
puts "- Successfully demonstrated IDX_I subscriptions:"
puts "  * Security ID 13: NIFTY (Nifty 50)"
puts "  * Security ID 25: BANKNIFTY (Nifty Bank)"
puts "  * Security ID 29: NIFTYIT (Nifty IT)"
puts "  * Security ID 51: SENSEX (Sensex)"
puts "- Used single connection to avoid rate limiting (429 errors)"
puts "- Proper connection cleanup prevents resource leaks"
puts "- No multiple connection issues!"
