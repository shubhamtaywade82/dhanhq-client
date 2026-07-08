# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

holdings = begin
  DhanHQ::Models::Holding.all
rescue StandardError
  []
end
positions = begin
  DhanHQ::Models::Position.all
rescue StandardError
  []
end
funds = begin
  DhanHQ::Models::Funds.fetch
rescue StandardError
  nil
end
trades = begin
  DhanHQ::Models::Trade.today
rescue StandardError
  []
end

summary = format_pnl_report(holdings, positions)

puts "=" * 50
puts "             PORTFOLIO SUMMARY"
puts "=" * 50
puts "\nHoldings count:   #{summary["holdings_count"]}"
puts "Positions count:  #{summary["positions_count"]}"
printf("Current value:    Rs. %12.2f\n", summary["current_value"])
printf("Total P&L:        Rs. %12.2f\n", summary["total_pnl"])
printf("Day P&L:          Rs. %12.2f\n", summary["day_pnl"])

if funds
  available = funds.availabel_balance || funds.available_balance || 0.0
  utilized = funds.utilized_amount || 0.0
  collateral = funds.collateral_amount || 0.0
  withdrawable = funds.withdrawable_balance || 0.0

  puts "\nFUNDS"
  printf("  Available:      Rs. %12.2f\n", available)
  printf("  Utilized:       Rs. %12.2f\n", utilized)
  printf("  Collateral:     Rs. %12.2f\n", collateral)
  printf("  Withdrawable:   Rs. %12.2f\n", withdrawable)
end

if holdings.any?
  puts "\nTOP HOLDINGS"
  # Sort holdings by quantity
  sorted_holdings = holdings.sort_by { |h| -(h.total_qty || 0) }
  sorted_holdings.first(5).each do |holding|
    printf("  %-15s qty=%5d available=%5d\n", holding.trading_symbol, holding.total_qty.to_i, holding.available_qty.to_i)
  end
end

open_positions = positions.reject { |p| p.net_qty.to_i.zero? }
if open_positions.any?
  puts "\nOPEN POSITIONS"
  open_positions.first(5).each do |position|
    pnl = position.realized_profit.to_f + position.unrealized_profit.to_f
    printf("  %-20s netQty=%5d pnl=Rs. %8.0f\n", position.trading_symbol, position.net_qty.to_i, pnl)
  end
end

puts "\nTrades today:     #{trades.size}"
puts "=" * 50
