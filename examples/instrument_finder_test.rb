#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for the new DhanHQ::Models::Instrument.find method
# This script demonstrates how to use the new .find and .find_anywhere methods

require "dhan_hq"

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["DHAN_CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["DHAN_ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

puts "DhanHQ Instrument Finder Test"
puts "============================="
puts "Testing the new .find and .find_anywhere methods"
puts ""

# Test 1: Find specific instruments in known segments
puts "1. Finding instruments in specific segments:"
puts "-" * 40

# Find RELIANCE in NSE_EQ (now uses underlying_symbol for equity)
reliance = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "RELIANCE")
if reliance
  puts "✅ RELIANCE:"
  puts "   Symbol Name: #{reliance.symbol_name}"
  puts "   Underlying Symbol: #{reliance.underlying_symbol}"
  puts "   Security ID: #{reliance.security_id}"
  puts "   Display Name: #{reliance.display_name}"
  puts "   Exchange Segment: #{reliance.exchange_segment}"
else
  puts "❌ RELIANCE not found"
end

puts

# Find TCS in NSE_EQ (now uses underlying_symbol for equity)
tcs = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "TCS")
if tcs
  puts "✅ TCS:"
  puts "   Symbol Name: #{tcs.symbol_name}"
  puts "   Underlying Symbol: #{tcs.underlying_symbol}"
  puts "   Security ID: #{tcs.security_id}"
  puts "   Display Name: #{tcs.display_name}"
  puts "   Exchange Segment: #{tcs.exchange_segment}"
else
  puts "❌ TCS not found"
end

puts

# Find NIFTY in IDX_I
nifty = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::IDX_I, "NIFTY")
if nifty
  puts "✅ NIFTY:"
  puts "   Security ID: #{nifty.security_id}"
  puts "   Display Name: #{nifty.display_name}"
  puts "   Exchange Segment: #{nifty.exchange_segment}"
else
  puts "❌ NIFTY not found"
end

puts

# Find BANKNIFTY in IDX_I
banknifty = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::IDX_I, "BANKNIFTY")
if banknifty
  puts "✅ BANKNIFTY:"
  puts "   Security ID: #{banknifty.security_id}"
  puts "   Display Name: #{banknifty.display_name}"
  puts "   Exchange Segment: #{banknifty.exchange_segment}"
else
  puts "❌ BANKNIFTY not found"
end

puts

# Test 2: Find instruments anywhere (cross-segment search)
puts "2. Finding instruments anywhere (cross-segment search):"
puts "-" * 50

# Find RELIANCE anywhere (now uses underlying_symbol for equity)
reliance_anywhere = DhanHQ::Models::Instrument.find_anywhere("RELIANCE", exact_match: true)
if reliance_anywhere
  puts "✅ RELIANCE found anywhere:"
  puts "   Symbol Name: #{reliance_anywhere.symbol_name}"
  puts "   Underlying Symbol: #{reliance_anywhere.underlying_symbol}"
  puts "   Security ID: #{reliance_anywhere.security_id}"
  puts "   Display Name: #{reliance_anywhere.display_name}"
  puts "   Exchange Segment: #{reliance_anywhere.exchange_segment}"
else
  puts "❌ RELIANCE not found anywhere"
end

puts

# Find TCS anywhere (now uses underlying_symbol for equity)
tcs_anywhere = DhanHQ::Models::Instrument.find_anywhere("TCS", exact_match: true)
if tcs_anywhere
  puts "✅ TCS found anywhere:"
  puts "   Symbol Name: #{tcs_anywhere.symbol_name}"
  puts "   Underlying Symbol: #{tcs_anywhere.underlying_symbol}"
  puts "   Security ID: #{tcs_anywhere.security_id}"
  puts "   Display Name: #{tcs_anywhere.display_name}"
  puts "   Exchange Segment: #{tcs_anywhere.exchange_segment}"
else
  puts "❌ TCS not found anywhere"
end

puts

# Find NIFTY anywhere
nifty_anywhere = DhanHQ::Models::Instrument.find_anywhere("NIFTY", exact_match: true)
if nifty_anywhere
  puts "✅ NIFTY found anywhere:"
  puts "   Security ID: #{nifty_anywhere.security_id}"
  puts "   Display Name: #{nifty_anywhere.display_name}"
  puts "   Exchange Segment: #{nifty_anywhere.exchange_segment}"
else
  puts "❌ NIFTY not found anywhere"
end

puts

# Test 3: Advanced search options
puts "3. Testing advanced search options:"
puts "-" * 35

# Test partial match
reliance_partial = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "RELIANCE")
if reliance_partial
  puts "✅ RELIANCE (partial match):"
  puts "   Symbol: #{reliance_partial.symbol_name}"
  puts "   Security ID: #{reliance_partial.security_id}"
else
  puts "❌ RELIANCE (partial match) not found"
end

puts

# Test case insensitive search
reliance_case = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, "reliance industries ltd", case_sensitive: false)
if reliance_case
  puts "✅ RELIANCE (case insensitive):"
  puts "   Symbol: #{reliance_case.symbol_name}"
  puts "   Security ID: #{reliance_case.security_id}"
else
  puts "❌ RELIANCE (case insensitive) not found"
end

puts

# Test 4: Practical usage for WebSocket subscriptions
puts "4. Practical usage for WebSocket subscriptions:"
puts "-" * 45

# Find instruments for Market Depth WebSocket
puts "Finding instruments for Market Depth WebSocket:"

market_depth_symbols = []
symbols_to_find = [
  { segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, symbol: "RELIANCE", name: "RELIANCE" },
  { segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, symbol: "TCS", name: "TCS" }
]

symbols_to_find.each do |search|
  instrument = DhanHQ::Models::Instrument.find(search[:segment], search[:symbol])
  if instrument
    market_depth_symbols << {
      symbol: search[:name],
      exchange_segment: instrument.exchange_segment,
      security_id: instrument.security_id
    }
    puts "✅ #{search[:name]}: #{instrument.exchange_segment}:#{instrument.security_id}"
  else
    puts "❌ #{search[:name]}: Not found"
  end
end

puts
puts "Market Depth WebSocket symbols array:"
puts market_depth_symbols.inspect

puts
puts "Test completed!"
puts "==============="
puts "The new .find and .find_anywhere methods make it easy to:"
puts "- Find instruments by exchange segment and symbol"
puts "- Search across multiple segments"
puts "- Use exact or partial matching"
puts "- Perform case-sensitive or case-insensitive searches"
puts "- Dynamically resolve symbols for WebSocket subscriptions"
