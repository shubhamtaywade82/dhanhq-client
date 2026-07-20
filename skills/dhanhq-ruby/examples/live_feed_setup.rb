# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "dhan_hq"
require_relative "../scripts/dhan_helpers"

# Initialize credentials
get_client

puts "Starting live market feed... (Ctrl+C to stop)"

# Connect in Ticker mode (LTP updates)
# Other available modes: :quote (OHLC + Volume), :full (full depth)
market_client = DhanHQ::WS.connect(mode: :ticker) do |tick|
  timestamp = tick[:ts] ? Time.at(tick[:ts]) : Time.now
  puts "Tick Received -> Segment: #{tick[:segment]}, SecID: #{tick[:security_id]}, LTP: #{tick[:ltp]} at #{timestamp}"
end

# Subscribe to target instruments
# segment must match exchange segment constants from Constants, e.g. "NSE_EQ", "IDX_I", etc.
market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, security_id: "2885")  # RELIANCE
market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, security_id: "1333")  # HDFCBANK
market_client.subscribe_one(segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ, security_id: "11536") # TCS

begin
  # Wait for feed to stream ticks
  sleep(15)
rescue Interrupt
  puts "\nStopping due to interrupt..."
ensure
  puts "Shutting down WebSocket..."
  begin
    market_client.stop
  rescue StandardError
    nil
  end
  begin
    DhanHQ::WS.disconnect_all_local!
  rescue StandardError
    nil
  end
  puts "Feed stopped."
end
