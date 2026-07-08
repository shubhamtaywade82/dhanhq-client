# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

security_id = "2885" # RELIANCE
price = 2450.0
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

# Uncomment after confirmation:
# order = DhanHQ::Models::Order.place(
#   security_id: security_id,
#   exchange_segment: "NSE_EQ",
#   transaction_type: "BUY",
#   quantity: quantity,
#   order_type: "LIMIT",
#   product_type: "CNC",
#   price: price,
#   validity: "DAY"
# )
# puts "Placed order ID: #{order.order_id}"
