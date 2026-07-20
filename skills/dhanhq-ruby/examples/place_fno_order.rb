# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(underlying_scrip: 13, underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I)
nearest_expiry = expiries.first

if nearest_expiry.nil?
  puts "Failed to fetch expiries."
  exit 1
end

puts "Nearest expiry: #{nearest_expiry}"

chain_df, spot = fetch_chain_df(under_security_id: 13, expiry: nearest_expiry)
atm = find_atm_row(chain_df, spot)

if atm.nil?
  puts "Failed to find ATM row."
  exit 1
end

ce_security_id = atm["ce_security_id"]
ce_ltp = atm["ce_ltp"].to_f
lot_size = get_lot_size(underlying: "NIFTY") || 75
quantity = lot_size

puts "Nifty spot: #{spot}"
puts "ATM strike: #{atm["strike"]}"
puts "CE security ID: #{ce_security_id}, LTP: Rs. #{"%.2f" % ce_ltp}"
puts

puts preview_order(
  security_id: ce_security_id,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_FNO,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: quantity,
  order_type: DhanHQ::Constants::OrderType::LIMIT,
  product_type: DhanHQ::Constants::ProductType::INTRADAY,
  price: ce_ltp,
  trading_symbol: "NIFTY #{atm["strike"].to_i} CE"
)

margin = check_margin(
  security_id: ce_security_id,
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_FNO,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: quantity,
  product_type: DhanHQ::Constants::ProductType::INTRADAY,
  price: ce_ltp
)

printf(
  "Margin check: sufficient=%s required=Rs. %s available=Rs. %s\n",
  margin["sufficient"].to_s,
  "%.2f" % margin["total_margin"],
  "%.2f" % margin["available_balance"]
)

# Uncomment only after confirmation:
# order = DhanHQ::Models::Order.place(
#   security_id: ce_security_id,
#   exchange_segment: "NSE_FNO",
#   transaction_type: "BUY",
#   quantity: quantity,
#   order_type: "LIMIT",
#   product_type: "INTRADAY",
#   price: ce_ltp,
#   validity: "DAY"
# )
# puts "Placed order ID: #{order.order_id}"
