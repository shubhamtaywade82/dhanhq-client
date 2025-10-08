# frozen_string_literal: true

require "json"
require "time"
require "date"

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

unless defined?(MarketCalendar)
  module MarketCalendar
    MARKET_HOLIDAYS = [
      Date.new(2025, 8, 15),
      Date.new(2025, 10, 2),
      Date.new(2025, 8, 27)
    ].freeze

    def self.weekday?(date)
      w = date.wday
      w >= 1 && w <= 5
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

    # Returns the trading day N days back from the given trading day.
    # Example: trading_days_ago(2025-10-07, 0) -> 2025-10-07 (if trading day)
    #          trading_days_ago(2025-10-07, 1) -> previous trading day
    def self.trading_days_ago(date, n)
      raise ArgumentError, "n must be >= 0" if n.to_i.negative?

      d = trading_day?(date) ? date : today_or_last_trading_day
      count = 0
      while count < n
        d = last_trading_day(from: d)
        count += 1
      end
      d
    end
  end
end

module TA
  class TechnicalAnalysis
    DEFAULTS = {
      rsi_period: 14,
      atr_period: 14,
      adx_period: 14,
      macd_fast: 12,
      macd_slow: 26,
      macd_signal: 9
    }.freeze

    def initialize(options = {})
      @opts = DEFAULTS.merge(options.transform_keys(&:to_sym))
    end

    def compute(exchange_segment:, instrument:, security_id:, from_date: nil, to_date: nil, days_back: nil,
                intervals: [1, 5, 15, 25, 60])
      if to_date.nil? || to_date.to_s.strip.empty?
        to_date = MarketCalendar.today_or_last_trading_day.strftime("%Y-%m-%d")
      end
      if (from_date.nil? || from_date.to_s.strip.empty?) && days_back && days_back.to_i > 0
        to_d = Date.parse(to_date)
        n_back = [days_back.to_i - 1, 0].max
        from_date = MarketCalendar.trading_days_ago(to_d, n_back).strftime("%Y-%m-%d")
      end
      from_date ||= to_date
      base_params = {
        exchange_segment: exchange_segment,
        instrument: instrument,
        security_id: security_id,
        from_date: from_date,
        to_date: to_date
      }

      one_min_candles = candles(fetch_intraday_windowed(base_params, 1))

      frames = {}
      intervals.each do |ivl|
        case ivl.to_i
        when 1 then frames[:m1]   = one_min_candles
        when 5 then frames[:m5]   = resample(one_min_candles, 5)
        when 15 then frames[:m15] = resample(one_min_candles, 15)
        when 25 then frames[:m25] = resample(one_min_candles, 25)
        when 60 then frames[:m60] = resample(one_min_candles, 60)
        end
      end

      {
        meta: {
          exchange_segment: exchange_segment,
          instrument: instrument,
          security_id: security_id,
          from_date: from_date,
          to_date: to_date
        },
        indicators: frames.transform_values { |candles| compute_for(candles) }
      }
    end

    def compute_from_file(path:, base_interval: 1, intervals: [1, 5, 15, 25, 60])
      raw = JSON.parse(File.read(path))
      base = candles(raw)
      frames = {}
      intervals.each do |ivl|
        case ivl.to_i
        when 1 then frames[:m1]   = (base_interval == 1 ? base : resample(base, 1))
        when 5 then frames[:m5]   = resample(base, 5)
        when 15 then frames[:m15] = resample(base, 15)
        when 25 then frames[:m25] = resample(base, 25)
        when 60 then frames[:m60] = resample(base, 60)
        end
      end
      { indicators: frames.transform_values { |candles| compute_for(candles) } }
    end

    private

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

    def candles(series)
      ts = series["timestamp"] || series[:timestamp]
      open = series["open"] || series[:open]
      high = series["high"] || series[:high]
      low  = series["low"]  || series[:low]
      close = series["close"] || series[:close]
      vol = series["volume"] || series[:volume]
      return [] unless ts && open && high && low && close && vol
      return [] if close.empty?

      (0...close.size).map do |i|
        { t: parse_time_like(ts[i]), o: open[i].to_f, h: high[i].to_f, l: low[i].to_f, c: close[i].to_f,
          v: vol[i].to_f }
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

    def compute_for(candles)
      c = closes(candles)
      h = highs(candles)
      l = lows(candles)
      return { rsi: nil, macd: { macd: nil, signal: nil, hist: nil }, adx: nil, atr: nil } if c.empty?

      {
        rsi: safe_last(rsi(c, @opts[:rsi_period])),
        macd: macd(c, @opts[:macd_fast], @opts[:macd_slow], @opts[:macd_signal]),
        adx: safe_last(adx(h, l, c, @opts[:adx_period])),
        atr: safe_last(atr(h, l, c, @opts[:atr_period]))
      }
    end

    def safe_last(arr)
      return nil unless arr.respond_to?(:last)

      arr.last
    rescue StandardError
      nil
    end

    # ---- Indicator adapters (mirror bin script) ----
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

    # ---- Simple fallbacks ----
    def ema(series, period)
      return nil if series.nil? || series.empty?

      k = 2.0 / (period + 1)
      series.each_with_index.reduce(nil) do |ema_prev, (v, i)|
        i == 0 ? v.to_f : (v.to_f * k) + ((ema_prev || v.to_f) * (1 - k))
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
          tr = [(high[i] - low[i]).abs, (high[i] - close[i - 1]).abs, (low[i] - close[i - 1]).abs].max
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
end
