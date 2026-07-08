# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

# Fetch LTP for Reliance
ltp_response = DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => [2885])
if ltp_response[:status] != "success"
  puts "Failed to fetch LTP: #{ltp_response[:remarks]}"
  exit 1
end

reliance_ltp = ltp_response[:data][DhanHQ::Constants::ExchangeSegment::NSE_EQ]["2885"]["last_price"].to_f
puts "Reliance LTP: Rs. #{"%.2f" % reliance_ltp}"

entry_price = reliance_ltp
target_price = (entry_price * 1.02).round(2)
sl_price = (entry_price * 0.99).round(2)
trailing_jump = 5.0

puts "\n--- Super Order Preview ---"
puts "Action:        BUY 1 share of RELIANCE"
puts "Entry Price:   Rs. #{"%.2f" % entry_price}"
puts "Target:        Rs. #{"%.2f" % target_price}"
puts "Stop Loss:     Rs. #{"%.2f" % sl_price}"
puts "Trailing Jump: Rs. #{"%.2f" % trailing_jump}"
puts "Product:       INTRADAY"

# Uncomment after confirmation:
# order = DhanHQ::Models::SuperOrder.create(
#   security_id: "2885",
#   exchange_segment: "NSE_EQ",
#   transaction_type: "BUY",
#   quantity: 1,
#   order_type: "LIMIT",
#   product_type: "INTRADAY",
#   price: entry_price,
#   target_price: target_price,
#   stop_loss_price: sl_price,
#   trailing_jump: trailing_jump
# )
#
# if order
#   puts "Super order placed: #{order.order_id} - #{order.order_status}"
#
#   # Connect to Order Update websocket to listen for updates
#   orders_client = DhanHQ::WS::Orders.connect do |update|
#     puts "Order Update -> OrderNo: #{update.order_no}, Status: #{update.status}"
#   end
#
#   sleep(10)
#   orders_client.stop rescue nil
# end
