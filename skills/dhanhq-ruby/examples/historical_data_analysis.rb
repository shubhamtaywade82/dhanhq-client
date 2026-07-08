# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require "date"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

to_date = Date.today.strftime("%Y-%m-%d")
from_date = (Date.today - 180).strftime("%Y-%m-%d")

# Fetch daily charts via HistoricalData model
candles = DhanHQ::Models::HistoricalData.daily(
  security_id: "2885",
  exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
  instrument: DhanHQ::Constants::InstrumentType::EQUITY,
  from_date: from_date,
  to_date: to_date
)

if candles.empty?
  puts "No candle data returned."
  exit 1
end

close_prices = candles.map { |c| c[:close].to_f }
timestamps = candles.map { |c| c[:timestamp] }

# Calculate SMAs
def calculate_sma(prices, period)
  return [] if prices.size < period

  # Calculate SMA for each index starting from period - 1
  ((period - 1)...prices.size).map do |i|
    prices[(i - period + 1)..i].sum / period.to_f
  end
end

sma_20_series = calculate_sma(close_prices, 20)
sma_50_series = calculate_sma(close_prices, 50)

latest_sma_20 = sma_20_series.last
latest_sma_50 = sma_50_series.last

# Calculate returns
returns = []
close_prices.each_cons(2) do |prev_price, curr_price|
  returns << ((curr_price - prev_price) / prev_price)
end

# Calculate daily volatility (standard deviation of returns) and annualize it
mean_return = returns.sum / returns.size.to_f
variance = returns.sum { |r| (r - mean_return)**2 } / (returns.size - 1).to_f
std_dev = Math.sqrt(variance)
annualized_volatility = std_dev * Math.sqrt(252)

start_date = begin
  timestamps.first.is_a?(Time) ? timestamps.first.to_date : Date.parse(timestamps.first.to_s)
rescue StandardError
  "N/A"
end
end_date = begin
  timestamps.last.is_a?(Time) ? timestamps.last.to_date : Date.parse(timestamps.last.to_s)
rescue StandardError
  "N/A"
end

puts "=== RELIANCE — Last 6 Months ===\n\n"
puts "Period:         #{start_date} to #{end_date}"
puts "Trading Days:   #{candles.size}"
puts "Start Price:    Rs. #{"%.2f" % close_prices.first}"
puts "End Price:      Rs. #{"%.2f" % close_prices.last}"
puts "High:           Rs. #{"%.2f" % candles.map { |c| c[:high].to_f }.max}"
puts "Low:            Rs. #{"%.2f" % candles.map { |c| c[:low].to_f }.min}"
puts "Total Return:   #{format("%.2f%", ((close_prices.last / close_prices.first) - 1.0) * 100)}"
puts "Avg Daily Vol:  #{format("%.0f", candles.sum { |c| c[:volume].to_i } / candles.size.to_f)}"
puts "Volatility:     #{format("%.2f%", annualized_volatility * 100)} (annualized)"

if latest_sma_20 && latest_sma_50
  puts "\nSMA 20:         Rs. #{"%.2f" % latest_sma_20}"
  puts "SMA 50:         Rs. #{"%.2f" % latest_sma_50}"
  if latest_sma_20 > latest_sma_50
    puts "Signal:         Bullish (SMA 20 > SMA 50)"
  else
    puts "Signal:         Bearish (SMA 20 < SMA 50)"
  end
end
