#!/usr/bin/env ruby
# frozen_string_literal: true

# Market Depth WebSocket Example
# This script demonstrates how to use the DhanHQ Market Depth WebSocket
# Receives real-time market depth data (bid/ask levels) for specific symbols
# NOTE: Uses a SINGLE connection to avoid rate limiting

require "dhan_hq"

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

puts "DhanHQ Market Depth WebSocket Example"
puts "===================================="
puts "Receives real-time market depth data including:"
puts "- Bid/Ask levels"
puts "- Order book information"
puts "- Market depth snapshots"
puts "- Depth updates"
puts ""
puts "Subscribing to popular stocks:"
puts "- RELIANCE (Reliance Industries) - NSE_EQ:2885"
puts "- TCS (Tata Consultancy Services) - NSE_EQ:11536"
puts ""
puts "NOTE: Using SINGLE connection to avoid rate limiting (429 errors)"
puts "Dhan allows up to 5 WebSocket connections per user"
puts ""

# Market Depth WebSocket Connection
puts "Market Depth WebSocket Connection"
puts "================================="

# Create a single market depth WebSocket connection
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
else
  puts "❌ Could not find RELIANCE INDUSTRIES LTD"
end

if tcs_instrument
  symbols << { symbol: "TCS", exchange_segment: tcs_instrument.exchange_segment,
               security_id: tcs_instrument.security_id }
  puts "✅ Found TCS: #{tcs_instrument.symbol_name} (#{tcs_instrument.exchange_segment}:#{tcs_instrument.security_id})"
else
  puts "❌ Could not find TATA CONSULTANCY SERV LT"
end

if symbols.empty?
  puts "❌ No symbols found. Exiting..."
  exit(1)
end

depth_client = DhanHQ::WS::MarketDepth.connect(symbols: symbols) do |depth_data|
  puts "Market Depth: #{depth_data[:symbol]}"
  puts "  Best Bid: #{depth_data[:best_bid]}"
  puts "  Best Ask: #{depth_data[:best_ask]}"
  puts "  Spread: #{depth_data[:spread]}"
  puts "  Bid Levels: #{depth_data[:bids].size}"
  puts "  Ask Levels: #{depth_data[:asks].size}"

  # Show top 3 bid/ask levels if available
  if depth_data[:bids]&.size&.positive?
    puts "  Top Bids:"
    depth_data[:bids].first(3).each_with_index do |bid, i|
      puts "    #{i + 1}. Price: #{bid[:price]}, Qty: #{bid[:quantity]}"
    end
  end

  if depth_data[:asks]&.size&.positive?
    puts "  Top Asks:"
    depth_data[:asks].first(3).each_with_index do |ask, i|
      puts "    #{i + 1}. Price: #{ask[:price]}, Qty: #{ask[:quantity]}"
    end
  end

  puts "  ---"
end

# Add event handlers for different depth events
puts "\nSetting up event handlers..."

depth_client.on(:depth_update) do |update_data|
  puts "📊 Depth Update: #{update_data[:symbol]} - #{update_data[:side]} side updated"
end

depth_client.on(:depth_snapshot) do |snapshot_data|
  puts "📸 Depth Snapshot: #{snapshot_data[:symbol]} - Full order book received"
end

depth_client.on(:error) do |error|
  puts "⚠️  WebSocket Error: #{error}"
end

depth_client.on(:close) do |close_info|
  if close_info.is_a?(Hash)
    puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
  else
    puts "🔌 WebSocket Closed: #{close_info}"
  end
end

puts "\nMarket Depth WebSocket connected successfully!"
puts "Waiting 30 seconds to receive market depth data..."
puts "Press Ctrl+C to stop early"
puts ""

# Wait for market depth data
begin
  sleep(30)
rescue Interrupt
  puts "\nStopping early due to user interrupt..."
end

# Graceful shutdown
puts "\nShutting down Market Depth WebSocket connection..."
depth_client.stop

puts "Market Depth WebSocket connection closed."
puts "Example completed!"
puts ""
puts "Summary:"
puts "- Successfully demonstrated Market Depth WebSocket"
puts "- Real-time bid/ask level tracking:"
puts "  * RELIANCE (Reliance Industries) - dynamically resolved using .find method"
puts "  * TCS (Tata Consultancy Services) - dynamically resolved using .find method"
puts "- Order book depth visualization"
puts "- Used single connection to avoid rate limiting (429 errors)"
puts "- Proper connection cleanup prevents resource leaks"
puts "- Dynamic symbol resolution using DhanHQ::Models::Instrument.find"
