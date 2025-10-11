#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "optparse"
require "json"
require "time"
require "date"
begin
  require "dotenv/load"
rescue StandardError => e
  warn ".env not loaded: #{e.message}"
end

begin
  require "ruby-technical-analysis"
rescue LoadError => e
  warn "ruby-technical-analysis not available: #{e.message}"
end

begin
  require "technical-analysis"
rescue LoadError => e
  warn "technical-analysis not available: #{e.message}"
end

require "DhanHQ"

# Simple market calendar to choose valid trading days (no Rails/Time.zone)
module MarketCalendar
  MARKET_HOLIDAYS = [
    # Update as needed
    Date.new(2025, 8, 15),
    Date.new(2025, 10, 2),
    Date.new(2025, 8, 27)
  ].freeze

  def self.weekday?(date)
    w = date.wday # 0=Sun, 6=Sat
    w.between?(1, 5)
  end

  def self.trading_day?(date)
    weekday?(date) && !MARKET_HOLIDAYS.include?(date)
  end

  def self.last_trading_day(from: Date.today)
    d = from
    d -= 1 until trading_day?(d)
    d
  end

  def self.today_or_last_trading_day
    trading_day?(Date.today) ? Date.today : last_trading_day(from: Date.today)
  end
end

# Default date range: most recent trading day
DEFAULT_TO_DATE = MarketCalendar.today_or_last_trading_day.strftime("%Y-%m-%d")
DEFAULT_FROM_DATE = DEFAULT_TO_DATE

DEFAULTS = {
  exchange_segment: "NSE_EQ",
  instrument: "EQUITY",
  security_id: "1333", # sample scrip
  from_date: DEFAULT_FROM_DATE,
  to_date: DEFAULT_TO_DATE,
  rsi_period: 14,
  atr_period: 14,
  adx_period: 14,
  macd_fast: 12,
  macd_slow: 26,
  macd_signal: 9
}.freeze

opts = DEFAULTS.dup
opts[:print_creds] = false
opts[:data_file] = nil
opts[:data_interval] = 1
opts[:debug] = false

OptionParser.new do |o|
  o.banner = "Usage: ta_strategy.rb [options]"
  o.on("--segment SEG", "Exchange segment, e.g. NSE_EQ/IDX_I/NSE_FNO") { |v| opts[:exchange_segment] = v }
  o.on("--instrument KIND", "EQUITY/INDEX") { |v| opts[:instrument] = v }
  o.on("--security-id ID", "SecurityId (string or integer)") { |v| opts[:security_id] = v }
  o.on("--from YYYY-MM-DD", "From date (inclusive)") { |v| opts[:from_date] = v }
  o.on("--to YYYY-MM-DD", "To date (inclusive)") { |v| opts[:to_date] = v }
  o.on("--rsi N", Integer, "RSI period (default: 14)") { |v| opts[:rsi_period] = v }
  o.on("--atr N", Integer, "ATR period (default: 14)") { |v| opts[:atr_period] = v }
  o.on("--adx N", Integer, "ADX period (default: 14)") { |v| opts[:adx_period] = v }
  o.on("--macd FAST,SLOW,SIGNAL", Array, "MACD periods (default: 12,26,9)") do |arr|
    fast, slow, sig = arr.map(&:to_i)
    opts[:macd_fast] = fast if fast&.positive?
    opts[:macd_slow] = slow if slow&.positive?
    opts[:macd_signal] = sig if sig&.positive?
  end
  o.on("--data-file PATH", "Read OHLC JSON from file instead of calling API") { |v| opts[:data_file] = v }
  o.on("--interval N", Integer, "Interval of --data-file in minutes (default: 1)") { |v| opts[:data_interval] = v }
  o.on("--debug", "Print debug info about OHLC sizes and last candles") { opts[:debug] = true }
  o.on("--print-creds", "Print CLIENT_ID and masked ACCESS_TOKEN, then continue") { opts[:print_creds] = true }
  o.on("-h", "--help") do
    puts o
    exit
  end
end.parse!

if opts[:print_creds]
  cid = ENV.fetch("CLIENT_ID", nil)
  tok = ENV.fetch("ACCESS_TOKEN", nil)
  masked = if tok && tok.size >= 8
             "#{tok[0, 4]}...#{tok[-4, 4]}"
           else
             (tok ? tok[0, 4] : nil)
           end
  puts "CLIENT_ID=#{cid.inspect}"
  puts "ACCESS_TOKEN=#{masked || "nil"}"
end

DhanHQ.configure_with_env

def fetch_intraday(params, interval)
  DhanHQ::Models::HistoricalData.intraday(
    security_id: params[:security_id],
    exchange_segment: params[:exchange_segment],
    instrument: params[:instrument],
    interval: interval.to_s,
    from_date: params[:from_date],
    to_date: params[:to_date]
  )
end

# The API allows max 90 days per call. If the requested window exceeds this,
# fetch in chunks and concatenate arrays chronologically.
def fetch_intraday_windowed(params, interval)
  from_d = Date.parse(params[:from_date])
  to_d   = Date.parse(params[:to_date])
  max_span = 90
  return fetch_intraday(params, interval) if (to_d - from_d).to_i <= max_span

  merged = { "open" => [], "high" => [], "low" => [], "close" => [], "volume" => [], "timestamp" => [] }
  cursor = from_d
  while cursor <= to_d
    chunk_to = [cursor + max_span, to_d].min
    chunk_params = params.merge(from_date: cursor.strftime("%Y-%m-%d"), to_date: chunk_to.strftime("%Y-%m-%d"))
    part = fetch_intraday(chunk_params, interval)
    %w[open high low close volume timestamp].each do |k|
      ary = (part[k] || part[k.to_sym]) || []
      merged[k].concat(Array(ary))
    end
    cursor = chunk_to + 1
  end
  merged
end

def parse_time_like(val)
  return Time.at(val) if val.is_a?(Numeric)

  s = val.to_s
  return Time.at(s.to_i) if /\A\d+\z/.match?(s) && s.length >= 10 && s.length <= 13

  Time.parse(s)
end

def to_candles(series)
  ts = series["timestamp"] || series[:timestamp]
  open = series["open"] || series[:open]
  high = series["high"] || series[:high]
  low  = series["low"]  || series[:low]
  close = series["close"] || series[:close]
  vol = series["volume"] || series[:volume]
  return [] unless ts && open && high && low && close && vol
  return [] if close.empty?

  (0...close.size).map do |i|
    {
      t: parse_time_like(ts[i]),
      o: open[i].to_f,
      h: high[i].to_f,
      l: low[i].to_f,
      c: close[i].to_f,
      v: vol[i].to_f
    }
  end
rescue StandardError
  []
end

def resample(candles, minutes)
  return candles if minutes == 1

  grouped = {}
  candles.each do |c|
    key = Time.at((c[:t].to_i / 60) / minutes * minutes * 60)
    b = (grouped[key] ||= { t: key, o: c[:o], h: c[:h], l: c[:l], c: c[:c], v: 0.0 })
    b[:h] = [b[:h], c[:h]].max
    b[:l] = [b[:l], c[:l]].min
    b[:c] = c[:c]
    b[:v] += c[:v]
  end
  grouped.keys.sort.map { |k| grouped[k] }
end

def closes(candles) = candles.map { |c| c[:c] }
def highs(candles)  = candles.map { |c| c[:h] }
def lows(candles)   = candles.map { |c| c[:l] }

module TAAdapters
  module_function

  def rsi(series, period)
    if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:RSI)
      return RubyTechnicalAnalysis::RSI.new(series: series, period: period).call
    end
    if defined?(TechnicalAnalysis) && TechnicalAnalysis.respond_to?(:rsi)
      return TechnicalAnalysis.rsi(series, period: period)
    end

    simple_rsi(series, period)
  end

  def macd(series, fast, slow, signal)
    if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:MACD)
      out = RubyTechnicalAnalysis::MACD.new(series: series, fast_period: fast, slow_period: slow,
                                            signal_period: signal).call
      if out.is_a?(Hash)
        m = out[:macd]
        s = out[:signal]
        h = out[:histogram] || out[:hist]
        m = m.last if m.is_a?(Array)
        s = s.last if s.is_a?(Array)
        h = h.last if h.is_a?(Array)
        return { macd: m, signal: s, hist: h }
      end
    end
    if defined?(TechnicalAnalysis) && TechnicalAnalysis.respond_to?(:macd)
      out = TechnicalAnalysis.macd(series, fast: fast, slow: slow, signal: signal)
      if out.is_a?(Hash)
        m = out[:macd]
        s = out[:signal]
        h = out[:hist]
        m = m.last if m.is_a?(Array)
        s = s.last if s.is_a?(Array)
        h = h.last if h.is_a?(Array)
        return { macd: m, signal: s, hist: h }
      end
    end
    simple_macd(series, fast, slow, signal)
  end

  def adx(high, low, close, period)
    if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:ADX)
      return RubyTechnicalAnalysis::ADX.new(high: high, low: low, close: close, period: period).call
    end
    if defined?(TechnicalAnalysis) && TechnicalAnalysis.respond_to?(:adx)
      return TechnicalAnalysis.adx(high: high, low: low, close: close, period: period)
    end

    simple_adx(high, low, close, period)
  end

  def atr(high, low, close, period)
    if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:ATR)
      return RubyTechnicalAnalysis::ATR.new(high: high, low: low, close: close, period: period).call
    end
    if defined?(TechnicalAnalysis) && TechnicalAnalysis.respond_to?(:atr)
      return TechnicalAnalysis.atr(high: high, low: low, close: close, period: period)
    end

    simple_atr(high, low, close, period)
  end

  # --- Minimal fallbacks (only last value accuracy needed for testing) ---
  def ema(series, period)
    return nil if series.nil? || series.empty?

    k = 2.0 / (period + 1)
    series.each_with_index.reduce(nil) do |ema_prev, (v, i)|
      if i.zero?
        v.to_f
      else
        (v.to_f * k) + ((ema_prev || v.to_f) * (1 - k))
      end
    end
  end

  def simple_rsi(series, period)
    gains = []
    losses = []
    series.each_cons(2) do |a, b|
      ch = b - a
      gains << [ch, 0].max
      losses << [(-ch), 0].max
    end
    avg_gain = gains.first(period).sum / period.to_f
    avg_loss = losses.first(period).sum / period.to_f
    rsi_vals = Array.new(series.size, nil)
    gains.drop(period).each_with_index do |g, idx|
      l = losses[period + idx]
      avg_gain = ((avg_gain * (period - 1)) + g) / period
      avg_loss = ((avg_loss * (period - 1)) + l) / period
      rs = avg_loss.zero? ? 100.0 : (avg_gain / avg_loss)
      rsi_vals[period + 1 + idx] = 100.0 - (100.0 / (1 + rs))
    end
    rsi_vals
  end

  def simple_macd(series, fast, slow, signal)
    e_fast = ema(series, fast)
    e_slow = ema(series, slow)
    e_sig  = ema(series, signal)
    return { macd: nil, signal: nil, hist: nil } if [e_fast, e_slow, e_sig].any?(&:nil?)

    macd_line = e_fast - e_slow
    signal_line = e_sig
    { macd: macd_line, signal: signal_line, hist: macd_line - signal_line }
  end

  def true_ranges(high, low, close)
    trs = []
    close.each_with_index do |_c, i|
      if i.zero?
        trs << (high[i] - low[i]).abs
      else
        tr = [
          (high[i] - low[i]).abs,
          (high[i] - close[i - 1]).abs,
          (low[i] - close[i - 1]).abs
        ].max
        trs << tr
      end
    end
    trs
  end

  def simple_atr(high, low, close, period)
    trs = true_ranges(high, low, close)
    out = []
    atr_prev = trs.first(period).sum / period.to_f
    trs.each_with_index do |tr, i|
      if i < period
        out << nil
      elsif i == period
        out << atr_prev
      else
        atr_prev = ((atr_prev * (period - 1)) + tr) / period.to_f
        out << atr_prev
      end
    end
    out
  end

  def simple_adx(high, low, close, period)
    plus_dm = [0]
    minus_dm = [0]
    (1...high.size).each do |i|
      up_move = high[i] - high[i - 1]
      down_move = low[i - 1] - low[i]
      plus_dm << (up_move > down_move && up_move.positive? ? up_move : 0)
      minus_dm << (down_move > up_move && down_move.positive? ? down_move : 0)
    end
    trs = true_ranges(high, low, close)
    smooth_tr = trs.first(period).sum
    smooth_plus_dm = plus_dm.first(period).sum
    smooth_minus_dm = minus_dm.first(period).sum
    adx_vals = Array.new(high.size, nil)
    di_vals = []
    (period...high.size).each do |i|
      smooth_tr = smooth_tr - (smooth_tr / period) + trs[i]
      smooth_plus_dm = smooth_plus_dm - (smooth_plus_dm / period) + plus_dm[i]
      smooth_minus_dm = smooth_minus_dm - (smooth_minus_dm / period) + minus_dm[i]
      plus_di = 100.0 * (smooth_plus_dm / smooth_tr)
      minus_di = 100.0 * (smooth_minus_dm / smooth_tr)
      dx = 100.0 * ((plus_di - minus_di).abs / (plus_di + minus_di))
      di_vals << dx
      adx_vals[i] = di_vals.last(period).sum / period.to_f if di_vals.size >= period
    end
    adx_vals
  end
end

def compute_for(candles, params)
  c = closes(candles)
  h = highs(candles)
  l = lows(candles)
  return { rsi: nil, macd: { macd: nil, signal: nil, hist: nil }, adx: nil, atr: nil } if c.empty?

  {
    rsi: begin
      TAAdapters.rsi(c, params[:rsi_period]).last
    rescue StandardError
      nil
    end,
    macd: TAAdapters.macd(c, params[:macd_fast], params[:macd_slow], params[:macd_signal]),
    adx: begin
      TAAdapters.adx(h, l, c, params[:adx_period]).last
    rescue StandardError
      nil
    end,
    atr: begin
      TAAdapters.atr(h, l, c, params[:atr_period]).last
    rescue StandardError
      nil
    end
  }
end

one_min = []
five_min = []
fifteen_min = []
twentyfive_min = []
sixty_min = []

if opts[:data_file]
  raw = JSON.parse(File.read(opts[:data_file]))
  base_ivl = opts[:data_interval].to_i
  case base_ivl
  when 1
    one_min = to_candles(raw)
    five_min = resample(one_min, 5)
    fifteen_min = resample(one_min, 15)
    twentyfive_min = resample(one_min, 25)
    sixty_min = resample(one_min, 60)
  when 5
    five_min = to_candles(raw)
    fifteen_min = resample(five_min, 15)
    twentyfive_min = resample(five_min, 25)
    sixty_min = resample(five_min, 60)
  when 15
    fifteen_min = to_candles(raw)
    sixty_min = resample(fifteen_min, 60)
  when 25
    twentyfive_min = to_candles(raw)
    # No exact 60 from 25; prefer fetching/resampling from 1m if needed
  when 60
    sixty_min = to_candles(raw)
  else
    one_min = to_candles(raw)
    five_min = resample(one_min, 5)
    fifteen_min = resample(one_min, 15)
    twentyfive_min = resample(one_min, 25)
    sixty_min = resample(one_min, 60)
  end
else
  raw_1 = fetch_intraday_windowed(opts, 1)
  one_min = to_candles(raw_1)
  five_min = resample(one_min, 5)
  fifteen_min = resample(one_min, 15)
  twentyfive_min = resample(one_min, 25)
  sixty_min = resample(one_min, 60)
end

if opts[:debug]
  puts "sizes m1=#{one_min.size} m5=#{five_min.size} m15=#{fifteen_min.size} m25=#{twentyfive_min.size} m60=#{sixty_min.size}"
  puts "last m1=#{one_min.last.inspect}" if one_min.any?
  puts "last m5=#{five_min.last.inspect}" if five_min.any?
  puts "last m15=#{fifteen_min.last.inspect}" if fifteen_min.any?
  puts "last m25=#{twentyfive_min.last.inspect}" if twentyfive_min.any?
  puts "last m60=#{sixty_min.last.inspect}" if sixty_min.any?
end

out = {
  meta: {
    exchange_segment: opts[:exchange_segment],
    instrument: opts[:instrument],
    security_id: opts[:security_id],
    from_date: opts[:from_date],
    to_date: opts[:to_date]
  },
  indicators: {
    m1: compute_for(one_min, opts),
    m5: compute_for(five_min, opts),
    m15: compute_for(fifteen_min, opts),
    m25: compute_for(twentyfive_min, opts),
    m60: compute_for(sixty_min, opts)
  }
}

puts JSON.pretty_generate(out)
