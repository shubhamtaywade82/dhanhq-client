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
require_relative "market_calendar"
require_relative "candles"
require_relative "indicators"
require_relative "fetcher"

module TA
  class TechnicalAnalysis
    DEFAULTS = {
      rsi_period: 14,
      atr_period: 14,
      adx_period: 14,
      macd_fast: 12,
      macd_slow: 26,
      macd_signal: 9,
      throttle_seconds: 1.0,
      max_retries: 3
    }.freeze

    def initialize(options = {})
      @opts = DEFAULTS.merge(options.transform_keys(&:to_sym))
      @fetcher = Fetcher.new(throttle_seconds: @opts[:throttle_seconds], max_retries: @opts[:max_retries])
    end

    def compute(exchange_segment:, instrument:, security_id:, from_date: nil, to_date: nil, days_back: nil,
                intervals: [1, 5, 15, 25, 60])
      # Normalize to_date: default to last trading day; if provided and non-trading, roll back
      to_date = normalize_to_date(to_date)

      # Auto-calculate required trading days if not provided
      days_back = auto_days_needed(intervals) if days_back.nil? || days_back.to_i <= 0

      # Derive/normalize from_date
      from_date = normalize_from_date(from_date, to_date, days_back)

      base_params = {
        exchange_segment: exchange_segment,
        instrument: instrument,
        security_id: security_id,
        from_date: from_date,
        to_date: to_date
      }

      frames = {}
      interval_key = { 1 => :m1, 5 => :m5, 15 => :m15, 25 => :m25, 60 => :m60 }
      intervals.each do |ivl|
        key = interval_key[ivl.to_i]
        next unless key

        raw = @fetcher.intraday_windowed(base_params, ivl.to_i)
        frames[key] = Candles.from_series(raw)
        sleep_with_jitter # throttle between intervals
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
      base = Candles.from_series(raw)
      frames = {}
      intervals.each do |ivl|
        case ivl.to_i
        when 1 then frames[:m1]   = (base_interval == 1 ? base : Candles.resample(base, 1))
        when 5 then frames[:m5]   = Candles.resample(base, 5)
        when 15 then frames[:m15] = Candles.resample(base, 15)
        when 25 then frames[:m25] = Candles.resample(base, 25)
        when 60 then frames[:m60] = Candles.resample(base, 60)
        end
      end
      { indicators: frames.transform_values { |candles| compute_for(candles) } }
    end

    private

    def sleep_with_jitter(multiplier = 1.0)
      base = (@opts[:throttle_seconds] || 3.0).to_f * multiplier
      jitter = rand * 0.3
      sleep(base + jitter)
    end

    def normalize_to_date(to_date)
      return MarketCalendar.today_or_last_trading_day.strftime("%Y-%m-%d") if to_date.nil? || to_date.to_s.strip.empty?

      to_d_raw = begin
        Date.parse(to_date)
      rescue StandardError
        nil
      end
      if to_d_raw && !MarketCalendar.trading_day?(to_d_raw)
        MarketCalendar.last_trading_day(from: to_d_raw).strftime("%Y-%m-%d")
      else
        to_date
      end
    end

    def normalize_from_date(from_date, to_date, days_back)
      if (from_date.nil? || from_date.to_s.strip.empty?) && days_back&.to_i&.positive?
        to_d = Date.parse(to_date)
        n_back = [days_back.to_i - 1, 0].max
        return MarketCalendar.trading_days_ago(to_d, n_back).strftime("%Y-%m-%d")
      end
      if from_date && !from_date.to_s.strip.empty?
        f_d_raw = begin
          Date.parse(from_date)
        rescue StandardError
          nil
        end
        if f_d_raw && !MarketCalendar.trading_day?(f_d_raw)
          fd = f_d_raw
          fd += 1 until MarketCalendar.trading_day?(fd)
          to_d = Date.parse(to_date)
          return [fd, to_d].min.strftime("%Y-%m-%d")
        end
        return from_date
      end
      to_date
    end

    # Calculate how many bars we need based on indicator periods
    def required_bars_for_indicators
      rsi_need = (@opts[:rsi_period] || 14).to_i + 1
      atr_need = (@opts[:atr_period] || 14).to_i + 1
      adx_need = (@opts[:adx_period] || 14).to_i * 2
      macd_need = (@opts[:macd_slow] || 26).to_i
      [rsi_need, atr_need, adx_need, macd_need].max
    end

    def bars_per_trading_day(interval_minutes)
      minutes = interval_minutes.to_i
      return 1 if minutes <= 0

      (375.0 / minutes).floor
    end

    def days_needed_for_interval(interval_minutes)
      need = required_bars_for_indicators
      per_day = [bars_per_trading_day(interval_minutes), 1].max
      ((need + per_day - 1) / per_day)
    end

    def auto_days_needed(intervals)
      Array(intervals).map { |ivl| days_needed_for_interval(ivl.to_i) }.max || 1
    end

    def compute_for(candles)
      c = candles.map { |k| k[:c] }
      h = candles.map { |k| k[:h] }
      l = candles.map { |k| k[:l] }
      return { rsi: nil, macd: { macd: nil, signal: nil, hist: nil }, adx: nil, atr: nil } if c.empty?

      {
        rsi: safe_last(Indicators.rsi(c, @opts[:rsi_period])),
        macd: Indicators.macd(c, @opts[:macd_fast], @opts[:macd_slow], @opts[:macd_signal]),
        adx: safe_last(Indicators.adx(h, l, c, @opts[:adx_period])),
        atr: safe_last(Indicators.atr(h, l, c, @opts[:atr_period]))
      }
    end

    def safe_last(arr)
      return nil unless arr.respond_to?(:last)

      arr.last
    rescue StandardError
      nil
    end
  end
end
