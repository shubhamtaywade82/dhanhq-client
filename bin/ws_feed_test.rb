#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "json"
require "logger"
require "optparse"
require "concurrent"
require "time"
require "fileutils"

begin
  require "dotenv/load"
rescue StandardError
  nil
end
require "DhanHQ"

# ---- Config & CLI ----
opts = {
  mode: "all",                 # ticker|quote|full|all
  watchlist: "watchlist.csv",  # CSV with segment,security_id
  log_dir: "log",
  rotate_size: 50 * 1024 * 1024,  # 50 MB per file
  rotate_age: 10,                 # keep 10 files
  print_every: 10                 # seconds
}

OptionParser.new do |o|
  o.banner = "Usage: ws_feed_test.rb [options]"
  o.on("--mode MODE", "ticker|quote|full|all (default: all)") { |v| opts[:mode] = v }
  o.on("--watchlist FILE", "CSV of segment,security_id")     { |v| opts[:watchlist] = v }
  o.on("--log-dir DIR", "Log output directory")              { |v| opts[:log_dir] = v }
  o.on("--rotate-size BYTES", Integer, "Log rotate size")    { |v| opts[:rotate_size] = v }
  o.on("--rotate-age N", Integer, "Log rotate count")        { |v| opts[:rotate_age] = v }
  o.on("--print-every SECS", Integer, "TPS print interval")  { |v| opts[:print_every] = v }
  o.on("-h", "--help") do
    puts o
    exit
  end
end.parse!

# ---- Dhan config ----
DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV["DHAN_LOG_LEVEL"] || "INFO").upcase.then { |lvl| Logger.const_get(lvl) }

# ---- Watchlist loader ----
def load_watchlist(path)
  list = []
  if File.exist?(path)
    File.foreach(path) do |line|
      next if line.strip.empty? || line.start_with?("#")

      seg, sid = line.strip.split(",", 2).map(&:strip)
      next unless seg && sid
      # Skip common header labels
      next if seg.casecmp("segment").zero? || seg.casecmp("exchange_segment").zero? || sid.casecmp("security_id").zero?
      # Only accept numeric security ids
      next unless /\A\d+\z/.match?(sid)

      canonical_seg = DhanHQ::WS::Segments.to_request_string(seg)
      # Validate segment against known enums
      next unless DhanHQ::WS::Segments::STRING_TO_CODE.key?(canonical_seg)

      list << { segment: canonical_seg, security_id: sid }
    end
  end
  if list.empty?
    list = [
      { segment: "IDX_I", security_id: "13" },  # NIFTY index value
      { segment: "IDX_I", security_id: "25" }   # BANKNIFTY index value
    ]
  end
  list
end

WATCH = load_watchlist(opts[:watchlist])

# ---- TickCache (thread-safe) ----
class TickCache
  MAP = Concurrent::Map.new

  class << self
    # Keyed by "SEG:SID"
    def put(t)
      MAP["#{t[:segment]}:#{t[:security_id]}"] = t.merge(updated_at: Time.now.to_i)
    end

    def get(segment, sid)
      MAP["#{segment}:#{sid}"]
    end

    def ltp(segment, sid)
      get(segment, sid)&.dig(:ltp)
    end

    def size
      MAP.size
    end

    def snapshot
      # Shallow copy for quick inspection
      MAP.dup
    end
  end
end

# ---- Logger per mode (rotating) ----
def make_logger(dir, mode, rotate_age, rotate_size)
  FileUtils.mkdir_p(dir)
  ts = Time.now.utc.strftime("%Y%m%d-%H%M%S")
  path = File.join(dir, "ticks_#{mode}_#{ts}.log")
  logger = Logger.new(path, rotate_age, rotate_size)
  logger.level = Logger::INFO
  logger.formatter = proc do |_severity, _time, _prog, msg|
    "#{msg}\n" # msg will be a JSON string
  end
  logger
end

def jsonl_for(mode, tick)
  # Ensure mode is tagged; the gem already gives kind/:segment/:security_id/:ltp, etc.
  tick = tick.merge(mode: mode, received_at: Time.now.utc.iso8601)
  JSON.generate(tick)
end

# ---- Wire a single WS client ----
def run_client(mode:, watch:, log:)
  ws = DhanHQ::WS::Client.new(mode: mode.to_sym).start
  count = Concurrent::AtomicFixnum.new(0)

  ws.on(:tick) do |t|
    puts jsonl_for(mode, t)
    TickCache.put(t)
    count.increment
    log.info jsonl_for(mode, t)
  end

  # Subscribe instruments (≤100 per frame recommended; call subscribe_one for each)
  watch.each { |i| ws.subscribe_one(segment: i[:segment], security_id: i[:security_id]) }

  [ws, count]
end

# ---- Main: start 1..3 clients ----
modes =
  case opts[:mode]
  when "ticker", "quote", "full"
    [opts[:mode]]
  else
    # Use a single connection in :full mode for "all" to avoid broker limits
    # (full already includes quote + ticker data)
    %w[quote]
  end

clients = []
counters = {}
loggers = {}

modes.each do |m|
  loggers[m] = make_logger(opts[:log_dir], m, opts[:rotate_age], opts[:rotate_size])
  ws, cnt = run_client(mode: m, watch: WATCH, log: loggers[m])
  clients << ws
  counters[m] = cnt
  # Stagger connection attempts to avoid concurrent handshakes/rate limits
  10.times do
    break if ws.connected?

    sleep 0.5
  end
  sleep 1.0
end

# ---- Stats printer ----
stop = Concurrent::AtomicBoolean.new(false)
printer = Thread.new do
  prev = counters.transform_values(&:value)
  until stop.true?
    sleep opts[:print_every]
    now = counters.transform_values(&:value)
    # Compute per-mode diffs only for active modes to avoid nil math
    diffs = {}
    now.each { |k, v| diffs[k] = v - (prev[k] || 0) }

    tps_parts = modes.map do |m|
      per_sec = (diffs.fetch(m, 0) / opts[:print_every].to_f).round(1)
      "#{m}=#{per_sec}"
    end

    puts "[#{Time.now.strftime("%H:%M:%S")}] TPS(#{tps_parts.join(", ")}) Cache=#{TickCache.size}"
    prev = now
  end
end

# ---- Graceful shutdown ----
shutdown = false
trap("INT")  { shutdown = true }
trap("TERM") { shutdown = true }

# Keep alive until a shutdown signal is received
sleep 0.5 until shutdown

# Perform shutdown work outside of trap context (thread-safe)
puts "\nStopping..."
stop.make_true
begin
  printer.join(1)
rescue StandardError => e
  DhanHQ.logger&.debug("[ws_feed_test] printer join error #{e.class}: #{e.message}")
end
clients.each(&:disconnect!)
DhanHQ::WS.disconnect_all_local!
exit
