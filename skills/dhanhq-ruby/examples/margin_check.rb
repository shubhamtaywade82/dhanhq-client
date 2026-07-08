# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

funds = DhanHQ::Models::Funds.fetch
available = funds.availabel_balance || funds.available_balance || 0.0
puts "Available Balance: Rs. #{"%.2f" % available}"

expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(underlying_scrip: 13, underlying_seg: DhanHQ::Constants::ExchangeSegment::IDX_I)
nearest_expiry = expiries.first

chain_df, spot = fetch_chain_df(under_security_id: 13, expiry: nearest_expiry)
atm = find_atm_row(chain_df, spot)

if atm
  puts "\n--- Margin Check: Buy 1 Lot Nifty CE (INTRADAY) ---"
  option_margin = check_margin(
    security_id: atm["ce_security_id"],
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_FNO,
    transaction_type: DhanHQ::Constants::TransactionType::BUY,
    quantity: 75,
    product_type: DhanHQ::Constants::ProductType::INTRADAY,
    price: atm["ce_ltp"].to_f
  )
  puts option_margin.inspect
end

puts "\n--- Margin Check: Buy 10 RELIANCE (CNC Delivery) ---"
equity_margin = check_margin(
  security_id: "2885",
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  transaction_type: DhanHQ::Constants::TransactionType::BUY,
  quantity: 10,
  product_type: DhanHQ::Constants::ProductType::CNC,
  price: 2450.0
)
puts equity_margin.inspect
