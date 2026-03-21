#!/usr/bin/env ruby
# frozen_string_literal: true

require "date"
require "securerandom"
require "dhan_hq"

DhanHQ.configure_with_env

# Example: Fetch historical market data using Dhan API in Ruby
bars = DhanHQ::Models::HistoricalData.intraday(
  security_id: "13",
  exchange_segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
  instrument: DhanHQ::Constants::InstrumentType::INDEX,
  interval: "5",
  from_date: Date.today.to_s,
  to_date: Date.today.to_s
)

if bars.size < 20
  warn "Need at least 20 bars to compute the signal. Received #{bars.size}."
  exit 1
end

closes = bars.map { |bar| bar[:close].to_f }
last_close = closes.last
sma20 = closes.last(20).sum / 20.0
signal = last_close > sma20 ? :bullish : :bearish

puts "NIFTY last close: #{last_close.round(2)}"
puts "NIFTY SMA20: #{sma20.round(2)}"
puts "Signal: #{signal}"

if signal == :bullish
  puts "Bullish setup detected. Example order payload:"

  # Example: Build a guarded order payload using the Ruby SDK for Dhan API
  order = DhanHQ::Models::Order.new(
    transaction_type: DhanHQ::Constants::TransactionType::BUY,
    exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    product_type: DhanHQ::Constants::ProductType::CNC,
    order_type: DhanHQ::Constants::OrderType::MARKET,
    validity: DhanHQ::Constants::Validity::DAY,
    security_id: "11536",
    quantity: 1,
    correlation_id: "BOT_#{SecureRandom.hex(4)}"
  )

  puts order.inspect
  puts "Set LIVE_TRADING=true only when you intend to place live orders."
  # order.save
else
  puts "No trade placed. Strategy stays flat on bearish conditions."
end
