#!/usr/bin/env ruby
# frozen_string_literal: true

# DhanHQ Trading Fields Example
# This script demonstrates how to use the new trading fields in the Instrument model
# for practical trading operations and risk management

require "dhan_hq"

# Configure DhanHQ
DhanHQ.configure do |config|
  config.client_id = ENV["CLIENT_ID"] || "your_client_id"
  config.access_token = ENV["ACCESS_TOKEN"] || "your_access_token"
  config.ws_user_type = ENV["DHAN_WS_USER_TYPE"] || "SELF"
end

puts "DhanHQ Trading Fields Example"
puts "============================="
puts "Demonstrating essential trading fields for risk management and order validation"
puts ""

# Helper method to display trading information
def display_trading_info(instrument, name)
  return unless instrument

  puts "✅ #{name} Trading Information:"
  puts "   Symbol: #{instrument.symbol_name}"
  puts "   Underlying Symbol: #{instrument.underlying_symbol}" if instrument.underlying_symbol
  puts "   Security ID: #{instrument.security_id}"
  puts "   ISIN: #{instrument.isin}"
  puts "   Instrument Type: #{instrument.instrument_type}"
  puts "   Exchange Segment: #{instrument.exchange_segment}"
  puts "   Lot Size: #{instrument.lot_size}"
  puts "   Tick Size: #{instrument.tick_size}"
  puts "   Expiry Flag: #{instrument.expiry_flag}"
  puts "   Bracket Flag: #{instrument.bracket_flag}"
  puts "   Cover Flag: #{instrument.cover_flag}"
  puts "   ASM/GSM Flag: #{instrument.asm_gsm_flag}"
  puts "   ASM/GSM Category: #{instrument.asm_gsm_category}" if instrument.asm_gsm_category != "NA"
  puts "   Buy/Sell Indicator: #{instrument.buy_sell_indicator}"
  puts "   Buy CO Min Margin %: #{instrument.buy_co_min_margin_per}"
  puts "   Sell CO Min Margin %: #{instrument.sell_co_min_margin_per}"
  puts "   MTF Leverage: #{instrument.mtf_leverage}"
  puts ""
end

# Helper method to check trading eligibility
def check_trading_eligibility(instrument, name)
  return unless instrument

  puts "🔍 #{name} Trading Eligibility Check:"

  # Check if instrument allows trading
  if instrument.buy_sell_indicator == "A"
    puts "   ✅ Trading Allowed"
  else
    puts "   ❌ Trading Not Allowed"
    return
  end

  # Check bracket orders
  if instrument.bracket_flag == "Y"
    puts "   ✅ Bracket Orders Allowed"
  else
    puts "   ❌ Bracket Orders Not Allowed"
  end

  # Check cover orders
  if instrument.cover_flag == "Y"
    puts "   ✅ Cover Orders Allowed"
  else
    puts "   ❌ Cover Orders Not Allowed"
  end

  # Check ASM/GSM status
  if instrument.asm_gsm_flag == "Y"
    puts "   ⚠️  ASM/GSM Applied: #{instrument.asm_gsm_category}"
  else
    puts "   ✅ No ASM/GSM Restrictions"
  end

  # Check expiry
  if instrument.expiry_flag == "Y"
    puts "   ⚠️  Instrument Has Expiry: #{instrument.expiry_date}"
  else
    puts "   ✅ No Expiry (Perpetual)"
  end

  puts ""
end

# Helper method to calculate margin requirements
def calculate_margin_requirements(instrument, name, quantity, price)
  return unless instrument

  puts "💰 #{name} Margin Calculation:"
  puts "   Quantity: #{quantity}"
  puts "   Price: ₹#{price}"
  puts "   Lot Size: #{instrument.lot_size}"

  total_value = quantity * price * instrument.lot_size
  puts "   Total Value: ₹#{total_value}"

  # Calculate margin requirements
  buy_margin = total_value * (instrument.buy_co_min_margin_per / 100.0)
  sell_margin = total_value * (instrument.sell_co_min_margin_per / 100.0)

  puts "   Buy CO Margin Required: ₹#{buy_margin}"
  puts "   Sell CO Margin Required: ₹#{sell_margin}"

  # Calculate MTF leverage
  if instrument.mtf_leverage > 0
    mtf_value = total_value * instrument.mtf_leverage
    puts "   MTF Leverage: #{instrument.mtf_leverage}x"
    puts "   MTF Value: ₹#{mtf_value}"
  end

  puts ""
end

puts "1. Finding Instruments with Trading Fields"
puts "=" * 50

# Find popular trading instruments
reliance = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
tcs = DhanHQ::Models::Instrument.find("NSE_EQ", "TCS")
hdfc = DhanHQ::Models::Instrument.find("NSE_EQ", "HDFC")
nifty = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")
banknifty = DhanHQ::Models::Instrument.find("IDX_I", "BANKNIFTY")

# Display trading information
display_trading_info(reliance, "RELIANCE")
display_trading_info(tcs, "TCS")
display_trading_info(hdfc, "HDFC")
display_trading_info(nifty, "NIFTY")
display_trading_info(banknifty, "BANKNIFTY")

puts "2. Trading Eligibility Checks"
puts "=" * 40

# Check trading eligibility
check_trading_eligibility(reliance, "RELIANCE")
check_trading_eligibility(tcs, "TCS")
check_trading_eligibility(nifty, "NIFTY")

puts "3. Margin Calculations"
puts "=" * 25

# Calculate margin requirements for different scenarios
calculate_margin_requirements(reliance, "RELIANCE", 10, 2500)
calculate_margin_requirements(tcs, "TCS", 5, 3500)
calculate_margin_requirements(nifty, "NIFTY", 1, 20_000)

puts "4. Practical Trading Scenarios"
puts "=" * 35

# Scenario 1: Check if instrument supports bracket orders
puts "Scenario 1: Bracket Order Support"
puts "-" * 30
instruments = [reliance, tcs, hdfc, nifty, banknifty]
instruments.each do |instrument|
  next unless instrument

  puts "#{instrument.underlying_symbol || instrument.symbol_name}: #{instrument.bracket_flag == "Y" ? "✅ Supports" : "❌ No Support"}"
end
puts ""

# Scenario 2: Find instruments with ASM/GSM restrictions
puts "Scenario 2: ASM/GSM Restricted Instruments"
puts "-" * 40
asm_instruments = instruments.select { |i| i&.asm_gsm_flag == "Y" }
if asm_instruments.any?
  asm_instruments.each do |instrument|
    puts "#{instrument.underlying_symbol || instrument.symbol_name}: #{instrument.asm_gsm_category}"
  end
else
  puts "No ASM/GSM restricted instruments found in sample"
end
puts ""

# Scenario 3: Find instruments with high MTF leverage
puts "Scenario 3: High MTF Leverage Instruments"
puts "-" * 40
high_leverage = instruments.select { |i| i&.mtf_leverage && i.mtf_leverage > 3.0 }
if high_leverage.any?
  high_leverage.each do |instrument|
    puts "#{instrument.underlying_symbol || instrument.symbol_name}: #{instrument.mtf_leverage}x leverage"
  end
else
  puts "No high leverage instruments found in sample"
end
puts ""

puts "5. Trading Field Summary"
puts "=" * 25
puts "Essential trading fields now available:"
puts "✅ ISIN - International Securities Identification Number"
puts "✅ Instrument Type - Classification (ES, INDEX, etc.)"
puts "✅ Expiry Flag - Whether instrument has expiry"
puts "✅ Bracket Flag - Bracket order support"
puts "✅ Cover Flag - Cover order support"
puts "✅ ASM/GSM Flag - Additional Surveillance Measure status"
puts "✅ Buy/Sell Indicator - Trading permission"
puts "✅ Margin Requirements - CO minimum margin percentages"
puts "✅ MTF Leverage - Margin Trading Facility leverage"
puts ""

puts "Example completed!"
puts "=================="
puts "These trading fields enable:"
puts "- Order validation and eligibility checks"
puts "- Margin requirement calculations"
puts "- Risk management and compliance"
puts "- Trading strategy implementation"
puts "- Regulatory compliance monitoring"
