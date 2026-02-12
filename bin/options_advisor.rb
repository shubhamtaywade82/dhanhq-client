#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "optparse"
require "json"
require "time"

begin
  require "dotenv/load"
rescue StandardError => e
  warn ".env not loaded: #{e.message}"
end

require "dhan_hq"
require "ta"

opts = {
  exchange_segment: "IDX_I",
  instrument: "INDEX",
  security_id: nil,
  symbol: nil,
  spot: nil,
  intervals: [1, 5, 15, 25, 60],
  throttle_seconds: 2.5,
  max_retries: 3,
  chain_file: nil,
  print_creds: false,
  debug: false
}

OptionParser.new do |o|
  o.banner = "Usage: options_advisor.rb [options]"
  o.on("--segment SEG", "Exchange segment (default: IDX_I)") { |v| opts[:exchange_segment] = v }
  o.on("--instrument KIND", "Instrument (INDEX recommended)") { |v| opts[:instrument] = v }
  o.on("--security-id ID", "SecurityId (e.g., 13 for NIFTY, 25 for BANKNIFTY)") { |v| opts[:security_id] = v }
  o.on("--symbol SYM", "Symbol label (e.g., NIFTY)") { |v| opts[:symbol] = v }
  o.on("--spot FLOAT", Float, "Current spot (optional; will fetch via MarketFeed.ltp if omitted)") do |v|
    opts[:spot] = v
  end
  o.on("--intervals LIST", "CSV of intervals (e.g., 1,5,15,25,60)") do |v|
    opts[:intervals] = v.split(",").map { |x| x.strip.to_i }
  end
  o.on("--chain-file PATH", "Option chain JSON file (optional; advisor will fetch if omitted)") do |v|
    opts[:chain_file] = v
  end
  o.on("--throttle-seconds N", Float, "Throttle seconds (default: 2.5)") { |v| opts[:throttle_seconds] = v }
  o.on("--max-retries N", Integer, "Max retries on rate limits (default: 3)") { |v| opts[:max_retries] = v }
  o.on("--debug", "Enable verbose debug logging to STDERR") { opts[:debug] = true }
  o.on("--print-creds", "Print DHAN_CLIENT_ID and masked DHAN_ACCESS_TOKEN, then continue") { opts[:print_creds] = true }
  o.on("-h", "--help") do
    puts o
    exit
  end
end.parse!

if opts[:print_creds]
  cid = ENV.fetch("DHAN_CLIENT_ID", nil)
  tok = ENV.fetch("DHAN_ACCESS_TOKEN", nil)
  masked = if tok && tok.size >= 8
             "#{tok[0, 4]}...#{tok[-4, 4]}"
           else
             (tok ? tok[0, 4] : nil)
           end
  puts "DHAN_CLIENT_ID=#{cid.inspect}"
  puts "DHAN_ACCESS_TOKEN=#{masked || "nil"}"
end

raise "--security-id is required" if opts[:security_id].to_s.strip.empty?

DhanHQ.configure_with_env

warn "[debug] opts: #{opts.except(:print_creds).inspect}" if opts[:debug]

# Resolve spot via MarketFeed.ltp if not provided
if opts[:spot].nil?
  begin
    warn "[debug] fetching LTP via MarketFeed.ltp for #{opts[:exchange_segment]}:#{opts[:security_id]}" if opts[:debug]
    ltp_payload = { opts[:exchange_segment] => [opts[:security_id].to_i] }
    ltp_resp = DhanHQ::Models::MarketFeed.ltp(ltp_payload)

    data = ltp_resp[:data] || ltp_resp["data"]
    seg_key = opts[:exchange_segment]
    sid_key = opts[:security_id].to_s
    last_price = nil
    if data && data[seg_key]
      node = data[seg_key][sid_key] || data[seg_key][sid_key.to_sym]
      last_price = node && (node[:last_price] || node["last_price"])
    end
    raise "LTP not available" unless last_price

    opts[:spot] = last_price.to_f
    warn "[debug] spot resolved: #{opts[:spot]}" if opts[:debug]
  rescue StandardError => e
    warn "Failed to fetch spot via MarketFeed.ltp: #{e.message}"
    exit 1
  end
elsif opts[:debug]
  warn "[debug] spot provided: #{opts[:spot]}"
end

# 1) Compute indicators for requested intervals
warn "[debug] computing indicators for intervals=#{opts[:intervals].inspect}" if opts[:debug]
tech = TA::TechnicalAnalysis.new(throttle_seconds: opts[:throttle_seconds], max_retries: opts[:max_retries])
indicator_data = tech.compute(
  exchange_segment: opts[:exchange_segment],
  instrument: opts[:instrument],
  security_id: opts[:security_id],
  intervals: opts[:intervals]
)
warn "[debug] indicators meta: #{indicator_data[:meta].inspect}" if opts[:debug]
if opts[:debug]
  nil_map = indicator_data[:indicators].transform_values do |h|
    keys = []
    keys << :rsi if h[:rsi].nil?
    keys << :adx if h[:adx].nil?
    keys << :atr if h[:atr].nil?
    keys << :macd if !h[:macd].is_a?(Hash) || [h[:macd][:macd], h[:macd][:signal], h[:macd][:hist]].any?(&:nil?)
    keys
  end
  warn "[debug] indicators nil fields per TF: #{nil_map.inspect}"
end

# 2) Option chain: load from file if provided (advisor can fetch if omitted)
chain = nil
if opts[:chain_file]
  begin
    warn "[debug] loading option chain from #{opts[:chain_file]}" if opts[:debug]
    chain = JSON.parse(File.read(opts[:chain_file]))
    warn "[debug] chain strikes (from file): #{chain.size}" if opts[:debug]
  rescue StandardError => e
    warn "Failed to read option chain file: #{e.message}"
  end
elsif opts[:debug]
  warn "[debug] no chain-file provided; advisor will fetch via OptionChain model"
end

# 3) Analyze (optional; useful for logging/visibility)
analyzer = DhanHQ::Analysis::MultiTimeframeAnalyzer.new(data: indicator_data)
summary = analyzer.call
warn "[debug] analyzer summary: #{summary[:summary].inspect}" if opts[:debug]

# 4) Build advisor payload
payload = {
  meta: indicator_data[:meta].merge(symbol: opts[:symbol] || "INDEX"),
  spot: opts[:spot],
  indicators: indicator_data[:indicators]
}
payload[:option_chain] = chain if chain

advisor = DhanHQ::Analysis::OptionsBuyingAdvisor.new(data: payload)
recommendation = advisor.call
warn "[debug] advisor output: #{recommendation.inspect}" if opts[:debug]

out = {
  indicators_meta: indicator_data[:meta],
  summary: summary[:summary],
  recommendation: recommendation
}

puts JSON.pretty_generate(out)
