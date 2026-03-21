#!/usr/bin/env ruby
# frozen_string_literal: true

require "dhan_hq"

DhanHQ.configure_with_env

nifty = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::IDX_I, "NIFTY")
expiry = ENV.fetch("DHAN_OPTION_EXPIRY", "2025-02-27")

puts "Options Watchlist"
puts "================="
puts "Underlying: #{nifty.trading_symbol} (#{nifty.security_id})"
puts "Expiry: #{expiry}"

chain = nifty.option_chain(expiry: expiry)

begin
  chain_rows = chain.respond_to?(:data) ? chain.data : Array(chain)
  chain_rows = Array(chain_rows)
  puts "Option-chain rows loaded: #{chain_rows.size}"
rescue StandardError
  puts "Option-chain payload received."
end

client = DhanHQ::WS.connect(mode: :quote) do |tick|
  puts "[#{Time.now.strftime("%H:%M:%S")}] #{tick[:security_id]} -> #{tick[:ltp]}"
end

client.subscribe_one(
  segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
  security_id: nifty.security_id
)

puts "Streaming NIFTY quotes for 20 seconds..."
sleep 20
client.stop
