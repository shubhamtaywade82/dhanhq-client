#!/usr/bin/env ruby
# frozen_string_literal: true

require "dhan_hq"

DhanHQ.configure_with_env

funds = DhanHQ::Models::Fund.balance
holdings = DhanHQ::Models::Holding.all
positions = DhanHQ::Models::Position.all

puts "Portfolio Monitor"
puts "================="
puts "Available cash: #{funds.respond_to?(:available_balance) ? funds.available_balance : funds.inspect}"
puts "Holdings count: #{holdings.count}"
puts "Open positions: #{positions.count}"
puts

holdings.first(5).each do |holding|
  symbol = holding.respond_to?(:trading_symbol) ? holding.trading_symbol : holding.inspect
  quantity = holding.respond_to?(:total_qty) ? holding.total_qty : "n/a"
  puts "Holding: #{symbol} | Qty: #{quantity}"
end

puts

positions.first(5).each do |position|
  symbol = position.respond_to?(:security_id) ? position.security_id : position.inspect
  side = position.respond_to?(:position_type) ? position.position_type : "n/a"
  pnl = position.respond_to?(:realized_profit) ? position.realized_profit : "n/a"
  puts "Position: #{symbol} | Type: #{side} | Realized P&L: #{pnl}"
end
