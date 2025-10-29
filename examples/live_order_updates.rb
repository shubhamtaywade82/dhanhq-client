#!/usr/bin/env ruby
# frozen_string_literal: true

# Live Order Updates Example
# Demonstrates comprehensive order state tracking via WebSocket

require_relative "lib/dhan_hq"

# Configure DhanHQ
DhanHQ.configure_with_env

puts "🚀 DhanHQ Live Order Updates Example"
puts "====================================="

# Create order tracking client
client = DhanHQ::WS::Orders.client

# Track order statistics
stats = {
  total_orders: 0,
  status_counts: Hash.new(0),
  executions: 0
}

# Set up comprehensive event handling
client.on(:update) do |order|
  stats[:total_orders] += 1
  stats[:status_counts][order.status] += 1

  puts "\n📋 Order Update: #{order.order_no}"
  puts "   Symbol: #{order.symbol} (#{order.display_name})"
  puts "   Status: #{order.status}"
  puts "   Type: #{order.txn_type} #{order.order_type}"
  puts "   Quantity: #{order.traded_qty}/#{order.quantity} (#{order.execution_percentage}%)"
  puts "   Price: #{order.price} | Avg: #{order.avg_traded_price}"

  puts "   Super Order Leg: #{order.leg_no}" if order.super_order?
end

client.on(:status_change) do |data|
  order = data[:order_update]
  puts "\n🔄 Status Change: #{order.order_no}"
  puts "   #{data[:previous_status]} -> #{data[:new_status]}"
end

client.on(:execution) do |data|
  order = data[:order_update]
  stats[:executions] += 1

  puts "\n💰 Execution: #{order.order_no}"
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

client.on(:order_cancelled) do |order|
  puts "\n🚫 Order Cancelled: #{order.order_no}"
end

client.on(:raw) do |msg|
  # Uncomment for debugging raw messages
  # puts "Raw: #{msg}"
end

# Start monitoring
puts "\n🔌 Connecting to order updates WebSocket..."
client.start

puts "✅ Connected! Monitoring order updates..."
puts "Press Ctrl+C to stop\n"

# Print periodic summaries
summary_timer = Thread.new do
  loop do
    sleep 30

    puts "\n📊 Order Summary (Last 30 seconds):"
    puts "   Total Updates: #{stats[:total_orders]}"
    puts "   Executions: #{stats[:executions]}"
    puts "   Status Distribution:"
    stats[:status_counts].each do |status, count|
      puts "     #{status}: #{count}"
    end

    # Show current order states
    all_orders = client.all_orders
    if all_orders.any?
      puts "   Current Orders:"
      all_orders.each do |order_no, order|
        puts "     #{order_no}: #{order.symbol} - #{order.status} (#{order.execution_percentage}%)"
      end
    end

    puts "\n#{"=" * 50}"
  end
end

# Keep running until interrupted
begin
  loop do
    sleep 1
  end
rescue Interrupt
  puts "\n\n🛑 Shutting down..."
  client.stop
  summary_timer.kill
  puts "✅ Disconnected. Goodbye!"
end
