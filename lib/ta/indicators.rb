# frozen_string_literal: true

module TA
  # Provides indicator calculations with fallbacks for external gems.
  module Indicators
    module_function

    # Calculates the exponential moving average for the provided series.
    #
    # @param series [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Float, nil]
    def ema(series, period)
      return nil if series.nil? || series.empty?

      k = 2.0 / (period + 1)
      series.each_with_index.reduce(nil) do |ema_prev, (v, i)|
        i.zero? ? v.to_f : (v.to_f * k) + ((ema_prev || v.to_f) * (1 - k))
      end
    end

    # Computes the Relative Strength Index.
    #
    # @param series [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Array<Float>, nil]
    def rsi(series, period)
      if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:RSI)
        return RubyTechnicalAnalysis::RSI.new(series: series, period: period).call
      end
      return TechnicalAnalysis.rsi(series, period: period) if defined?(TechnicalAnalysis) &&
                                                              TechnicalAnalysis.respond_to?(:rsi)

      simple_rsi(series, period)
    end

    # Computes the Moving Average Convergence Divergence values.
    #
    # @param series [Enumerable<Numeric>]
    # @param fast [Integer]
    # @param slow [Integer]
    # @param signal [Integer]
    # @return [Hash]
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

    # Calculates the Average Directional Index.
    #
    # @param high [Enumerable<Numeric>]
    # @param low [Enumerable<Numeric>]
    # @param close [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Array<Float>, Numeric]
    def adx(high, low, close, period)
      if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:ADX)
        return RubyTechnicalAnalysis::ADX.new(high: high, low: low, close: close, period: period).call
      end
      if defined?(TechnicalAnalysis) && TechnicalAnalysis.respond_to?(:adx)
        return TechnicalAnalysis.adx(high: high, low: low, close: close, period: period)
      end

      simple_adx(high, low, close, period)
    end

    # Calculates the Average True Range.
    #
    # @param high [Enumerable<Numeric>]
    # @param low [Enumerable<Numeric>]
    # @param close [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Array<Float>, Numeric]
    def atr(high, low, close, period)
      if defined?(RubyTechnicalAnalysis) && RubyTechnicalAnalysis.const_defined?(:ATR)
        return RubyTechnicalAnalysis::ATR.new(high: high, low: low, close: close, period: period).call
      end
      if defined?(TechnicalAnalysis) && TechnicalAnalysis.respond_to?(:atr)
        return TechnicalAnalysis.atr(high: high, low: low, close: close, period: period)
      end

      simple_atr(high, low, close, period)
    end

    # Lightweight RSI implementation used when external gems are unavailable.
    #
    # @param series [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Array<Float>]
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

    # Fallback MACD implementation.
    #
    # @param series [Enumerable<Numeric>]
    # @param fast [Integer]
    # @param slow [Integer]
    # @param signal [Integer]
    # @return [Hash]
    def simple_macd(series, fast, slow, signal)
      e_fast = ema(series, fast)
      e_slow = ema(series, slow)
      e_sig  = ema(series, signal)
      return { macd: nil, signal: nil, hist: nil } if [e_fast, e_slow, e_sig].any?(&:nil?)

      macd_line = e_fast - e_slow
      signal_line = e_sig
      { macd: macd_line, signal: signal_line, hist: macd_line - signal_line }
    end

    # Computes true ranges for ATR/ADX calculations.
    #
    # @param high [Enumerable<Numeric>]
    # @param low [Enumerable<Numeric>]
    # @param close [Enumerable<Numeric>]
    # @return [Array<Float>]
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

    # Simple ATR implementation used when faster dependencies are missing.
    #
    # @param high [Enumerable<Numeric>]
    # @param low [Enumerable<Numeric>]
    # @param close [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Array<Float>]
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

    # Simple ADX implementation used when faster dependencies are missing.
    #
    # @param high [Enumerable<Numeric>]
    # @param low [Enumerable<Numeric>]
    # @param close [Enumerable<Numeric>]
    # @param period [Integer]
    # @return [Array<Float>]
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
