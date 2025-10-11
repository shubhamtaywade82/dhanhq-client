# frozen_string_literal: true

require "time"

module TA
  # Utilities for working with candle time series data.
  module Candles
    module_function

    def parse_time_like(val)
      return Time.at(val) if val.is_a?(Numeric)

      s = val.to_s
      return Time.at(s.to_i) if /\A\d+\z/.match?(s) && s.length >= 10 && s.length <= 13

      Time.parse(s)
    end

    def from_series(series)
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
      return candles if minutes.to_i == 1

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
  end
end
