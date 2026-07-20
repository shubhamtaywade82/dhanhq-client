# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

# Example 1: Single GTT — Buy Reliance if it dips to ₹2300
puts "--- GTT Single: Buy RELIANCE on dip ---"
# order = DhanHQ::Models::ForeverOrder.create(
#   security_id: "2885",
#   exchange_segment: "NSE_EQ",
#   transaction_type: "BUY",
#   product_type: "CNC",              # Equity delivery
#   order_type: "LIMIT",
#   quantity: 5,
#   price: 2300.00,                   # Limit price
#   trigger_price: 2305.00,           # Trigger price
#   order_flag: "SINGLE",
#   validity: "DAY"
# )
# puts "GTT placed: #{order.inspect}"

# Example 2: OCO — Sell Reliance at ₹2700 (target) OR ₹2200 (stop loss)
puts "\n--- GTT OCO: Target + Stop Loss for RELIANCE holding ---"
# order = DhanHQ::Models::ForeverOrder.create(
#   security_id: "2885",
#   exchange_segment: "NSE_EQ",
#   transaction_type: "SELL",
#   product_type: "CNC",              # Selling from holdings
#   order_type: "LIMIT",
#   quantity: 5,
#   price: 2700.00,                   # Target price (price of first leg)
#   trigger_price: 2695.00,           # Target trigger price (trigger of first leg)
#   price1: 2200.00,                  # Stop loss price (price of second leg)
#   trigger_price1: 2205.00,          # Stop loss trigger price (trigger of second leg)
#   quantity1: 5,                     # Stop loss quantity (quantity of second leg)
#   order_flag: "OCO",                # One Cancels Other
#   validity: "DAY"
# )
# puts "OCO placed: #{order.inspect}"

# Example 3: List all active forever orders
puts "\n--- Active Forever Orders ---"
forever_orders = begin
  DhanHQ::Models::ForeverOrder.all
rescue StandardError
  []
end
if forever_orders.any?
  forever_orders.each do |ord|
    puts "  ID: #{ord.order_id} | " \
         "#{ord.trading_symbol} | " \
         "Type: #{ord.order_flag} | " \
         "Trigger: ₹#{ord.trigger_price}"
  end
else
  puts "  No active forever orders"
end

# Example 4: Cancel a forever order
# order = DhanHQ::Models::ForeverOrder.find("YOUR_ORDER_ID")
# order.cancel if order
