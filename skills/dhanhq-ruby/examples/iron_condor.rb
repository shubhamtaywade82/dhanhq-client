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

chain_df, spot = fetch_chain_df(under_security_id: 13, expiry: nearest_expiry)
puts "Nifty Spot: #{spot}, Expiry: #{nearest_expiry}"

strike_prices = chain_df.map { |r| r["strike"] }.sort
sell_ce_strike = strike_prices.min_by { |x| (x - (spot + 200)).abs }
buy_ce_strike = sell_ce_strike + 200
sell_pe_strike = strike_prices.min_by { |x| (x - (spot - 200)).abs }
buy_pe_strike = sell_pe_strike - 200

def get_row(chain_df, target_strike)
  chain_df.find { |r| r["strike"] == target_strike }
end

sell_ce = get_row(chain_df, sell_ce_strike)
buy_ce = get_row(chain_df, buy_ce_strike)
sell_pe = get_row(chain_df, sell_pe_strike)
buy_pe = get_row(chain_df, buy_pe_strike)

if [sell_ce, buy_ce, sell_pe, buy_pe].any?(&:nil?)
  puts "Could not find all required strikes. Try different offsets."
  exit 1
end

lot_size = get_lot_size(underlying: "NIFTY") || 75
legs = [
  {
    "label" => "Sell #{sell_pe_strike.to_i} PE",
    "type" => "PE",
    "strike" => sell_pe_strike,
    "premium" => sell_pe["pe_ltp"].to_f,
    "qty" => -1,
    "sid" => sell_pe["pe_security_id"]
  },
  {
    "label" => "Buy #{buy_pe_strike.to_i} PE",
    "type" => "PE",
    "strike" => buy_pe_strike,
    "premium" => buy_pe["pe_ltp"].to_f,
    "qty" => 1,
    "sid" => buy_pe["pe_security_id"]
  },
  {
    "label" => "Sell #{sell_ce_strike.to_i} CE",
    "type" => "CE",
    "strike" => sell_ce_strike,
    "premium" => sell_ce["ce_ltp"].to_f,
    "qty" => -1,
    "sid" => sell_ce["ce_security_id"]
  },
  {
    "label" => "Buy #{buy_ce_strike.to_i} CE",
    "type" => "CE",
    "strike" => buy_ce_strike,
    "premium" => buy_ce["ce_ltp"].to_f,
    "qty" => 1,
    "sid" => buy_ce["ce_security_id"]
  }
]

net_premium = legs.sum { |leg| -leg["qty"] * leg["premium"] }

# Evaluate payoffs
spot_range = []
current_spot = spot - 1000
while current_spot <= spot + 1000
  spot_range << current_spot
  current_spot += 10
end

payoffs = spot_range.map do |s|
  payoff_sum = 0.0
  legs.each do |leg|
    intrinsic = if leg["type"] == "CE"
                  [s - leg["strike"], 0.0].max
                else
                  [leg["strike"] - s, 0.0].max
                end
    payoff_sum += (intrinsic - leg["premium"]) * leg["qty"] * lot_size
  end
  payoff_sum
end

max_profit = payoffs.max
max_loss = payoffs.min

# Find breakevens where sign changes
breakevens = []
(0...(payoffs.size - 1)).each do |i|
  next unless (payoffs[i] >= 0 && payoffs[i + 1].negative?) || (payoffs[i].negative? && payoffs[i + 1] >= 0)

  # Linear interpolation for zero crossing
  x1 = spot_range[i]
  y1 = payoffs[i]
  x2 = spot_range[i + 1]
  y2 = payoffs[i + 1]
  zero_spot = x1 - (y1 * (x2 - x1) / (y2 - y1))
  breakevens << zero_spot
end

puts "\n======================================================="
puts "  NIFTY IRON CONDOR — Expiry: #{nearest_expiry}"
puts "======================================================="
puts "\n  Legs:"
legs.each do |leg|
  action = leg["qty"].negative? ? DhanHQ::Constants::TransactionType::SELL : "BUY "
  puts "    #{action} 1 lot #{leg["label"]} @ Rs. #{"%.1f" % leg["premium"]}"
end

puts "\n  Analysis (1 lot = #{lot_size} qty):"
printf("    Net Premium:   Rs. %8.0f (%s)\n", net_premium * lot_size, net_premium.positive? ? "credit" : "debit")
printf("    Max Profit:    Rs. %8.0f\n", max_profit)
printf("    Max Loss:      Rs. %8.0f\n", max_loss)
puts "    Breakevens:    #{breakevens.map { |b| "%.0f" % b }.join(", ")}"
puts "    Risk/Reward:   1:#{format("%.1f", max_profit / max_loss.abs)}" if max_loss != 0

puts "\n  Orders to place after confirmation:"
legs.each do |leg|
  action = leg["qty"].negative? ? DhanHQ::Constants::TransactionType::SELL : DhanHQ::Constants::TransactionType::BUY
  puts "    #{action} #{lot_size} qty | SID: #{leg["sid"]} | Rs. #{"%.1f" % leg["premium"]}"
end
