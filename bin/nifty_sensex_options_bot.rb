#!/usr/bin/env ruby
# frozen_string_literal: true

# Paper-trading bot for naked ATM index option buying on NIFTY / SENSEX.
#
# Strategy (validated in scratch/STRATEGY.md against a full year of real
# historical ATM option premium data — see that file for the backtest
# methodology and results):
#   - Entry: RSI(14) on 15-minute underlying candles crosses above 60 (buy
#     ATM Call) or below 40 (buy ATM Put). One position per underlying at a
#     time, no daily trend filter (the best-performing combo ran with the
#     regime filter off).
#   - Stop-loss: NOT a % of option premium. Exit when the underlying closes
#     back through the *entry candle's own* high/low — i.e. the breakout
#     that triggered entry has been invalidated at the index level.
#   - Target: +30% of option premium.
#   - Hard end-of-day square-off (default 15:20 IST) regardless of state.
#
# THIS SCRIPT NEVER PLACES REAL ORDERS. It logs what it would have done to
# log/paper_trades.jsonl for review. Wiring it to DhanHQ::Resources::Orders
# for live execution is a deliberate separate step — do not add it here
# without re-reading the caveats in scratch/STRATEGY.md first (no slippage
# modeling, no hard floor on the underlying-based stop, single-year backtest).
#
# Usage:
#   bundle exec ruby bin/nifty_sensex_options_bot.rb
#   bundle exec ruby bin/nifty_sensex_options_bot.rb --poll-seconds 30
#   bundle exec ruby bin/nifty_sensex_options_bot.rb --once   # single pass, for testing/cron

require "bundler/setup"
require "optparse"
require "json"
require "date"
require "time"
require "logger"
require "fileutils"

begin
  require "dotenv/load"
rescue LoadError => e
  warn ".env not loaded: #{e.message}"
end

require "dhan_hq"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

# Lot sizes are fetched at startup from the instrument master (see resolve_lot_size!)
# rather than hardcoded — they change periodically and a stale hardcoded value would
# silently misstate capital/margin. fallback_lot_size is used only if that lookup fails
# (values current as of 2026-07-08; treat as fallback only, per this repo's CLAUDE.md).
UNDERLYINGS = [
  { name: "NIFTY", security_id: "13", exchange_segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
    option_exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_FNO, strike_step: 50, fallback_lot_size: 65 },
  { name: "SENSEX", security_id: "51", exchange_segment: DhanHQ::Constants::ExchangeSegment::IDX_I,
    option_exchange_segment: DhanHQ::Constants::ExchangeSegment::BSE_FNO, strike_step: 100, fallback_lot_size: 20 }
].freeze

RSI_PERIOD = 14
RSI_BULL_TRIGGER = 60
RSI_BEAR_TRIGGER = 40
TARGET_PCT = 0.30
MIN_ENTRY_PREMIUM = 5.0 # guards against the ExpiredOptionsData-style sentinel/illiquid-quote issue found in backtesting
MARKET_OPEN = "09:15"
EOD_SQUARE_OFF = "15:20"
MARKET_CLOSE = "15:30"

LOG_DIR = File.join(__dir__, "..", "log")
TRADE_LOG_PATH = File.join(LOG_DIR, "paper_trades.jsonl")

options = { poll_seconds: 60, once: false }
OptionParser.new do |opts|
  opts.banner = "Usage: nifty_sensex_options_bot.rb [options]"
  opts.on("--poll-seconds N", Integer, "Seconds between polls (default 60)") { |v| options[:poll_seconds] = v }
  opts.on("--once", "Run a single pass and exit (for cron/testing)") { options[:once] = true }
end.parse!

FileUtils.mkdir_p(LOG_DIR)

LOGGER = Logger.new($stdout)
LOGGER.level = Logger::INFO
LOGGER.formatter = proc { |sev, time, _prog, msg| "[#{time.strftime("%Y-%m-%d %H:%M:%S")}] #{sev}: #{msg}\n" }

DhanHQ.configure_with_env

# ---------------------------------------------------------------------------
# IST time helpers (no Rails / ActiveSupport::TimeZone available)
# ---------------------------------------------------------------------------

def now_ist
  Time.now.getlocal("+05:30")
end

def ist_hm(time)
  time.strftime("%H:%M")
end

def market_open?(time = now_ist)
  return false if time.saturday? || time.sunday?

  ist_hm(time) >= MARKET_OPEN && ist_hm(time) < MARKET_CLOSE
end

def past_square_off?(time = now_ist)
  ist_hm(time) >= EOD_SQUARE_OFF
end

# ---------------------------------------------------------------------------
# Indicators
# ---------------------------------------------------------------------------

def rsi(closes, period = 14)
  return [] if closes.size < period + 1

  gains = []
  losses = []
  closes.each_cons(2) do |prev, curr|
    delta = curr - prev
    gains << [delta, 0].max
    losses << [-delta, 0].max
  end

  rsis = []
  avg_gain = gains.first(period).sum / period.to_f
  avg_loss = losses.first(period).sum / period.to_f
  rsis << (avg_loss.zero? ? 100.0 : 100.0 - (100.0 / (1 + (avg_gain / avg_loss))))

  (period...gains.size).each do |i|
    avg_gain = (((avg_gain * (period - 1)) + gains[i]) / period)
    avg_loss = (((avg_loss * (period - 1)) + losses[i]) / period)
    rsis << (avg_loss.zero? ? 100.0 : 100.0 - (100.0 / (1 + (avg_gain / avg_loss))))
  end

  rsis
end

# ---------------------------------------------------------------------------
# Data fetch helpers
# ---------------------------------------------------------------------------

def today_candles(underlying)
  today = Date.today
  data = DhanHQ::Models::HistoricalData.intraday(
    security_id: underlying[:security_id],
    exchange_segment: underlying[:exchange_segment],
    instrument: DhanHQ::Constants::InstrumentType::INDEX,
    interval: "15",
    from_date: today.to_s,
    to_date: (today + 1).to_s
  )
  data.is_a?(Array) ? data.sort_by { |c| c[:timestamp] } : []
rescue StandardError => e
  LOGGER.error("[#{underlying[:name]}] intraday fetch failed: #{e.message}")
  []
end

def nearest_expiry(underlying)
  expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
    underlying_scrip: underlying[:security_id].to_i,
    underlying_seg: underlying[:exchange_segment]
  )
  expiries.min_by { |e| (Date.parse(e) - Date.today).abs }
rescue StandardError => e
  LOGGER.error("[#{underlying[:name]}] expiry list fetch failed: #{e.message}")
  nil
end

def atm_row(underlying, expiry, spot)
  chain = DhanHQ::Models::OptionChain.fetch(
    underlying_scrip: underlying[:security_id].to_i,
    underlying_seg: underlying[:exchange_segment],
    expiry: expiry
  )
  strikes = chain[:strikes] || []
  return nil if strikes.empty?

  target = (spot / underlying[:strike_step]).round * underlying[:strike_step]
  strikes.min_by { |s| (s[:strike] - target).abs }
rescue StandardError => e
  LOGGER.error("[#{underlying[:name]}] option chain fetch failed: #{e.message}")
  nil
end

def log_trade(event)
  File.open(TRADE_LOG_PATH, "a") { |f| f.puts(event.merge(logged_at: now_ist.iso8601).to_json) }
end

# Resolves the current lot size for an underlying's index options from the
# instrument master (not the option chain, which doesn't carry lot_size).
# Called once at startup — by_segment loads the full segment CSV, too
# expensive to call per poll.
def resolve_lot_size(underlying)
  instruments = DhanHQ::Models::Instrument.by_segment(underlying[:option_exchange_segment])
  rows = instruments.select do |i|
    i.underlying_symbol.to_s == underlying[:name] && i.instrument_type == "OP"
  end
  lot_size = rows.min_by { |r| r.expiry_date.to_s }&.lot_size&.to_i
  lot_size&.positive? ? lot_size : underlying[:fallback_lot_size]
rescue StandardError => e
  LOGGER.error("[#{underlying[:name]}] lot size lookup failed, using fallback #{underlying[:fallback_lot_size]}: #{e.message}")
  underlying[:fallback_lot_size]
end

LOT_SIZES = UNDERLYINGS.to_h do |u|
  size = resolve_lot_size(u)
  LOGGER.info("[#{u[:name]}] lot_size=#{size}")
  [u[:name], size]
end

# ---------------------------------------------------------------------------
# Per-underlying state machine
# ---------------------------------------------------------------------------

# Tracks one underlying's current trading day: first-candle range, the
# last processed candle timestamp, and any open paper position.
class UnderlyingState
  attr_accessor :date, :first_candle, :last_seen_timestamp, :position

  def initialize(name)
    @name = name
    reset_for_new_day!
  end

  def reset_for_new_day!
    @date = Date.today
    @first_candle = nil
    @last_seen_timestamp = nil
    @position = nil
  end

  def new_day?
    @date != Date.today
  end
end

STATES = UNDERLYINGS.to_h { |u| [u[:name], UnderlyingState.new(u[:name])] }

def process_underlying(underlying, state)
  state.reset_for_new_day! if state.new_day?
  return unless market_open?

  candles = today_candles(underlying)
  return if candles.empty?

  state.first_candle ||= candles.first

  # Force EOD square-off regardless of signal state.
  if state.position && past_square_off?
    exit_position!(underlying, state, candles.last, "EOD")
    return
  end

  return if past_square_off?

  new_candles = state.last_seen_timestamp ? candles.select { |c| c[:timestamp] > state.last_seen_timestamp } : candles
  return if new_candles.empty?

  state.last_seen_timestamp = candles.last[:timestamp]

  if state.position
    manage_open_position(underlying, state, candles)
  else
    check_for_entry(underlying, state, candles)
  end
end

def check_for_entry(underlying, state, candles)
  return if candles.size < RSI_PERIOD + 2

  closes = candles.map { |c| c[:c] || c[:close] }
  rsis = rsi(closes, RSI_PERIOD)
  return if rsis.size < 2

  rsi_now = rsis.last
  rsi_prev = rsis[-2]

  direction =
    if rsi_prev <= RSI_BULL_TRIGGER && rsi_now > RSI_BULL_TRIGGER
      "CE"
    elsif rsi_prev >= RSI_BEAR_TRIGGER && rsi_now < RSI_BEAR_TRIGGER
      "PE"
    end
  return unless direction

  entry_candle = candles.last
  spot = entry_candle[:close] || entry_candle[:c]

  expiry = nearest_expiry(underlying)
  return unless expiry

  row = atm_row(underlying, expiry, spot)
  return unless row

  side = direction == "CE" ? row[:call] : row[:put]
  entry_premium = side["last_price"].to_f
  if entry_premium < MIN_ENTRY_PREMIUM
    LOGGER.warn("[#{underlying[:name]}] signal fired but entry_premium=#{entry_premium} below MIN_ENTRY_PREMIUM, skipping (likely stale/illiquid quote)")
    return
  end

  lot_size = LOT_SIZES.fetch(underlying[:name])
  capital = (entry_premium * lot_size).round(2)

  state.position = {
    direction: direction,
    strike: row[:strike],
    expiry: expiry,
    entry_premium: entry_premium,
    entry_time: entry_candle[:timestamp],
    entry_candle_high: entry_candle[:high] || entry_candle[:h],
    entry_candle_low: entry_candle[:low] || entry_candle[:l],
    target_price: entry_premium * (1 + TARGET_PCT),
    lot_size: lot_size,
    capital: capital
  }

  LOGGER.info(
    "[#{underlying[:name]}] ENTRY #{direction} strike=#{row[:strike]} premium=#{entry_premium} " \
    "lot_size=#{lot_size} capital=Rs.#{capital} target=#{state.position[:target_price].round(2)} " \
    "(RSI #{rsi_prev.round(1)}->#{rsi_now.round(1)})"
  )
  log_trade(
    event: "ENTRY", underlying: underlying[:name], direction: direction, strike: row[:strike],
    expiry: expiry, entry_premium: entry_premium, target_price: state.position[:target_price].round(2),
    lot_size: lot_size, capital: capital
  )
end

def manage_open_position(underlying, state, candles)
  pos = state.position
  latest_candle = candles.last
  underlying_close = latest_candle[:close] || latest_candle[:c]

  stop_hit =
    if pos[:direction] == "CE"
      underlying_close < pos[:entry_candle_low]
    else
      underlying_close > pos[:entry_candle_high]
    end

  if stop_hit
    exit_position!(underlying, state, latest_candle, "UNDERLYING_STOP")
    return
  end

  row = atm_row(underlying, pos[:expiry], underlying_close)
  return unless row

  side = if row[:strike] == pos[:strike]
           pos[:direction] == "CE" ? row[:call] : row[:put]
         end
  return unless side

  current_premium = side["last_price"].to_f
  return if current_premium <= 0

  exit_position!(underlying, state, latest_candle, "TARGET", current_premium) if current_premium >= pos[:target_price]
end

def exit_position!(underlying, state, exit_candle, reason, exit_premium = nil)
  pos = state.position

  if exit_premium.nil?
    row = atm_row(underlying, pos[:expiry], exit_candle[:close] || exit_candle[:c])
    side = row && (pos[:direction] == "CE" ? row[:call] : row[:put])
    exit_premium = side ? side["last_price"].to_f : pos[:entry_premium]
  end

  pnl_pct = ((exit_premium - pos[:entry_premium]) / pos[:entry_premium] * 100).round(2)
  pnl_rupees = ((exit_premium - pos[:entry_premium]) * pos[:lot_size]).round(2)

  LOGGER.info(
    "[#{underlying[:name]}] EXIT (#{reason}) #{pos[:direction]} entry=#{pos[:entry_premium]} " \
    "exit=#{exit_premium.round(2)} pnl=#{pnl_pct}% (Rs.#{pnl_rupees} on lot_size=#{pos[:lot_size]})"
  )
  log_trade(
    event: "EXIT", underlying: underlying[:name], direction: pos[:direction], reason: reason,
    entry_premium: pos[:entry_premium], exit_premium: exit_premium.round(2), pnl_pct: pnl_pct,
    lot_size: pos[:lot_size], capital: pos[:capital], pnl_rupees: pnl_rupees
  )

  state.position = nil
end

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

LOGGER.info("=" * 70)
LOGGER.info("PAPER TRADING MODE — no real orders will be placed.")
LOGGER.info("Strategy: rsi_only entry, entry_candle_invalidation stop, target=#{(TARGET_PCT * 100).round}%")
LOGGER.info("Trade log: #{TRADE_LOG_PATH}")
LOGGER.info("=" * 70)

trap("INT") do
  LOGGER.info("Interrupted, shutting down.")
  exit(0)
end

loop do
  if market_open?
    UNDERLYINGS.each { |u| process_underlying(u, STATES[u[:name]]) }
  else
    LOGGER.info("Market closed (IST #{ist_hm(now_ist)}), idling.")
  end

  break if options[:once]

  sleep(options[:poll_seconds])
end
