#!/usr/bin/env ruby
# frozen_string_literal: true

# Order Update WebSocket Example
# This script demonstrates how to use the DhanHQ Order Update WebSocket
# Receives real-time order status updates and execution notifications
# NOTE: Uses a SINGLE connection to avoid rate limiting

require "dhan_hq"

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

puts "DhanHQ Order Update WebSocket Example"
puts "====================================="
puts "Receives real-time order updates including:"
puts "- Order status changes"
puts "- Execution notifications"
puts "- Order rejections"
puts "- Trade confirmations"
puts ""
puts "NOTE: Using SINGLE connection to avoid rate limiting (429 errors)"
puts "Dhan allows up to 5 WebSocket connections per user"
puts ""

# Order Update WebSocket Connection
puts "Order Update WebSocket Connection"
puts "================================="

# Create a single order update WebSocket connection
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

# Add event handlers for different order events
puts "\nSetting up event handlers..."

orders_client.on(:update) do |order_update|
  puts "📝 Order Updated: #{order_update.order_no} - #{order_update.status}"
end

orders_client.on(:status_change) do |change_data|
  puts "🔄 Status Changed: #{change_data[:previous_status]} -> #{change_data[:new_status]}"
end

orders_client.on(:execution) do |execution_data|
  puts "✅ Execution: #{execution_data[:new_traded_qty]} shares executed"
end

orders_client.on(:order_traded) do |order_update|
  puts "💰 Order Traded: #{order_update.order_no} - #{order_update.symbol}"
end

orders_client.on(:order_rejected) do |order_update|
  puts "❌ Order Rejected: #{order_update.order_no} - #{order_update.reason_description}"
end

orders_client.on(:error) do |error|
  puts "⚠️  WebSocket Error: #{error}"
end

orders_client.on(:close) do |close_info|
  if close_info.is_a?(Hash)
    puts "🔌 WebSocket Closed: #{close_info[:code]} - #{close_info[:reason]}"
  else
    puts "🔌 WebSocket Closed: #{close_info}"
  end
end

puts "\nOrder Update WebSocket connected successfully!"
puts "Waiting 30 seconds to receive order updates..."
puts "Press Ctrl+C to stop early"
puts ""

# Wait for order updates
begin
  sleep(30)
rescue Interrupt
  puts "\nStopping early due to user interrupt..."
end

# Graceful shutdown
puts "\nShutting down Order Update WebSocket connection..."
orders_client.stop

puts "Order Update WebSocket connection closed."
puts "Example completed!"
puts ""
puts "Summary:"
puts "- Successfully demonstrated Order Update WebSocket"
puts "- Real-time order status tracking"
puts "- Multiple event handlers for different order events"
puts "- Used single connection to avoid rate limiting (429 errors)"
puts "- Proper connection cleanup prevents resource leaks"
