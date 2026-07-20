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

puts "Using expiry: #{nearest_expiry}"

chain_df, spot = fetch_chain_df(under_security_id: 13, expiry: nearest_expiry)
atm = find_atm_row(chain_df, spot)

if atm.nil?
  puts "Failed to find ATM row."
  exit 1
end

puts "Nifty Spot: #{spot}"
puts "ATM Strike: #{atm["strike"]}"

# Filter strikes between ATM - 500 and ATM + 500
nearby = chain_df.select do |row|
  row["strike"].between?(atm["strike"] - 500, atm["strike"] + 500)
end

puts "\nOption Chain (ATM ± 500 points):\n\n"
printf(
  "%-10s | %-8s | %-12s | %-6s | %-8s | %-12s | %-6s\n",
  "Strike", "CE LTP", "CE OI", "CE IV", "PE LTP", "PE OI", "PE IV"
)
puts "-" * 75
nearby.each do |row|
  printf(
    "%-10g | %-8.2f | %-12d | %-6.2f | %-8.2f | %-12d | %-6.2f\n",
    row["strike"],
    row["ce_ltp"].to_f,
    row["ce_oi"].to_i,
    row["ce_iv"].to_f,
    row["pe_ltp"].to_f,
    row["pe_oi"].to_i,
    row["pe_iv"].to_f
  )
end
puts
