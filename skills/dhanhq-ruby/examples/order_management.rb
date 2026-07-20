# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

security_id = "2885"
price = 2000.0
quantity = 1

puts preview_order(
  security_id: security_id,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: quantity,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  product_type: DhanHQ::Constants::ProductType::CNC,
  price: price,
  trading_symbol: "RELIANCE"
)

if ENV["RUN_LIVE_EXAMPLE"] != "1"
  puts "Set RUN_LIVE_EXAMPLE=1 to place, modify, and cancel a live demo order."
  exit 0
end

# Step 1: Place a limit order (well below market for demo — won't fill)
puts "Step 1: Placing limit buy order for RELIANCE..."
order = DhanHQ::Models::Order.place(
  security_id: security_id,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: quantity,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  product_type: DhanHQ::Constants::ProductType::CNC,
  price: price, # Below market — will stay pending
  validity: DhanHQ::Constants::Validity::DAY
)

if order.nil? || order.order_id.to_s.empty?
  puts "Order failed to place."
  exit 1
end

order_id = order.order_id
puts "Order placed: #{order_id}"

# Step 2: Check order status
puts "\nStep 2: Checking order status..."
sleep(1)
order = DhanHQ::Models::Order.find(order_id)
status = order.order_status
puts "Status: #{status}"
puts "  Security:  #{order.trading_symbol}"
puts "  Qty:       #{order.quantity}"
puts "  Price:     ₹#{order.price}"
puts "  Filled:    #{order.filled_qty || 0}"

# Step 3: Modify the order (change price)
if status == DhanHQ::Constants::OrderStatus::PENDING
  puts "\nStep 3: Modifying order price to ₹2050..."
  modified_order = order.modify(
    order_type: DhanHQ::Constants::OrderType::LIMIT,
    quantity: quantity,
    price: 2050.00,
    validity: DhanHQ::Constants::Validity::DAY
  )
  puts "Modify result: #{modified_order ? "Success" : "Failure"}"
end

# Step 4: Cancel the order
puts "\nStep 4: Cancelling order..."
cancel_success = order.cancel
puts "Cancel result: #{cancel_success ? "Success" : "Failure"}"

# Step 5: View order book
puts "\nStep 5: Today's order book:"
orders = begin
  DhanHQ::Models::Order.all
rescue StandardError
  []
end
if orders.any?
  orders.last(5).each do |o| # Last 5 orders
    printf("  %-12s | %-12s | %-4s | %-12s | ₹%-8.2f\n", o.order_id.to_s[0...12], o.trading_symbol, o.transaction_type, o.order_status, o.price.to_f)
  end
end

# Step 6: View trade book
puts "\nStep 6: Today's trade book:"
trades = begin
  DhanHQ::Models::Trade.today
rescue StandardError
  []
end
if trades.any?
  trades.last(5).each do |t|
    printf("  %-12s | %-4s | Qty: %-5d | ₹%-8.2f\n", t.trading_symbol, t.transaction_type, t.traded_quantity, t.traded_price.to_f)
  end
else
  puts "  No trades today"
end
