# frozen_string_literal: true

module DhanHQ
  # Technical analysis indicators for market data analysis.
  module Indicators
    # Simple Moving Average (SMA)
    #
    # Calculates the average of a specified number of data points.
    #
    # @example Calculate 20-period SMA
    #   closes = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109]
    #   sma = DhanHQ::Indicators::SMA.calculate(closes, period: 5)
    #   #=> [102.2, 103.0, 103.8, 104.6, 105.4, 106.8, 108.2, 107.8]
    #
    class SMA
      # Calculate SMA for the given data.
      #
      # @param data [Array<Numeric>] Input price data
      # @param period [Integer] Number of periods (default: 20)
      # @return [Array<Float>] SMA values (nil for insufficient data points)
      def self.calculate(data, period: 20)
        return [] if data.nil? || data.empty? || period < 1

        data.each_index.map do |i|
          next nil if i < period - 1

          window = data[(i - period + 1)..i]
          window.sum.to_f / period
        end
      end
    end

    # Exponential Moving Average (EMA)
    #
    # Weighted average that gives more importance to recent prices.
    #
    # @example Calculate 12-period EMA
    #   closes = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109]
    #   ema = DhanHQ::Indicators::EMA.calculate(closes, period: 5)
    #
    class EMA
      # Calculate EMA for the given data.
      #
      # @param data [Array<Numeric>] Input price data
      # @param period [Integer] Number of periods (default: 20)
      # @return [Array<Float>] EMA values (nil for insufficient data points)
      def self.calculate(data, period: 20)
        return [] if data.nil? || data.empty? || period < 1

        multiplier = 2.0 / (period + 1)
        ema_values = []

        data.each_with_index do |price, i|
          if i < period - 1
            ema_values << nil
          elsif i == period - 1
            # First EMA is SMA
            window = data[0..i]
            ema_values << (window.sum.to_f / period)
          else
            # EMA = (Price - Previous EMA) * Multiplier + Previous EMA
            previous_ema = ema_values.last
            ema_values << (((price - previous_ema) * multiplier) + previous_ema)
          end
        end

        ema_values
      end
    end

    # Relative Strength Index (RSI)
    #
    # Momentum oscillator measuring speed and magnitude of price changes.
    #
    # @example Calculate 14-period RSI
    #   closes = [100, 102, 101, 103, 105, 104, 106, 108, 107, 109, 111, 110, 112, 114, 113]
    #   rsi = DhanHQ::Indicators::RSI.calculate(closes, period: 14)
    #
    class RSI
      # Calculate RSI for the given data.
      #
      # @param data [Array<Numeric>] Input price data
      # @param period [Integer] Number of periods (default: 14)
      # @return [Array<Float>] RSI values (nil for insufficient data points)
      def self.calculate(data, period: 14)
        return [] if data.nil? || data.empty? || period < 1
        return [] if data.length < period + 1

        # Calculate price changes
        changes = data.each_cons(2).map { |a, b| b - a }

        # Calculate initial average gains and losses
        gains = changes[0...period].select(&:positive?)
        losses = changes[0...period].select(&:negative?).map(&:abs)

        avg_gain = gains.sum.to_f / period
        avg_loss = losses.sum.to_f / period

        rsi_values = Array.new(period, nil)

        # Calculate RSI for first period
        rsi_values << calculate_rsi(avg_gain, avg_loss)

        # Calculate subsequent RSI values
        changes[period..].each do |change|
          gain = change.positive? ? change : 0
          loss = change.negative? ? change.abs : 0

          avg_gain = ((avg_gain * (period - 1)) + gain) / period
          avg_loss = ((avg_loss * (period - 1)) + loss) / period

          rsi_values << calculate_rsi(avg_gain, avg_loss)
        end

        rsi_values
      end

      def self.calculate_rsi(avg_gain, avg_loss)
        return 100.0 if avg_loss.zero?
        return 0.0 if avg_gain.zero?

        rs = avg_gain / avg_loss
        100 - (100 / (1 + rs))
      end
      private_class_method :calculate_rsi
    end

    # Moving Average Convergence Divergence (MACD)
    #
    # Trend-following momentum indicator showing relationship between two EMAs.
    #
    # @example Calculate MACD
    #   closes = (0..99).map { |i| 100 + Math.sin(i * 0.1) * 10 }
    #   macd = DhanHQ::Indicators::MACD.calculate(closes)
    #   #=> { macd_line: [...], signal_line: [...], histogram: [...] }
    #
    class MACD
      # Calculate MACD for the given data.
      #
      # @param data [Array<Numeric>] Input price data
      # @param fast_period [Integer] Fast EMA period (default: 12)
      # @param slow_period [Integer] Slow EMA period (default: 26)
      # @param signal_period [Integer] Signal line period (default: 9)
      # @return [Hash] Hash with :macd_line, :signal_line, and :histogram arrays
      def self.calculate(data, fast_period: 12, slow_period: 26, signal_period: 9)
        return { macd_line: [], signal_line: [], histogram: [] } if data.nil? || data.empty?

        # Calculate fast and slow EMAs
        fast_ema = EMA.calculate(data, period: fast_period)
        slow_ema = EMA.calculate(data, period: slow_period)

        # Calculate MACD line (fast EMA - slow EMA)
        macd_line = fast_ema.zip(slow_ema).map do |fast, slow|
          next nil if fast.nil? || slow.nil?

          fast - slow
        end

        # Calculate signal line (EMA of MACD line)
        valid_macd = macd_line.compact
        signal_line_raw = valid_macd.empty? ? [] : EMA.calculate(valid_macd, period: signal_period)

        # Align signal line with MACD line
        signal_line = Array.new(macd_line.length - signal_line_raw.length, nil) + signal_line_raw

        # Calculate histogram (MACD line - signal line)
        histogram = macd_line.zip(signal_line).map do |macd, signal|
          next nil if macd.nil? || signal.nil?

          macd - signal
        end

        {
          macd_line: macd_line,
          signal_line: signal_line,
          histogram: histogram
        }
      end
    end

    # Bollinger Bands
    #
    # Volatility indicator consisting of three lines: middle band (SMA), upper band, lower band.
    #
    # @example Calculate Bollinger Bands
    #   closes = (0..99).map { |i| 100 + Math.sin(i * 0.1) * 10 }
    #   bb = DhanHQ::Indicators::BollingerBands.calculate(closes)
    #   #=> { upper: [...], middle: [...], lower: [...] }
    #
    class BollingerBands
      # Calculate Bollinger Bands for the given data.
      #
      # @param data [Array<Numeric>] Input price data
      # @param period [Integer] Number of periods (default: 20)
      # @param std_dev [Float] Number of standard deviations (default: 2.0)
      # @return [Hash] Hash with :upper, :middle, and :lower arrays
      def self.calculate(data, period: 20, std_dev: 2.0)
        return { upper: [], middle: [], lower: [] } if data.nil? || data.empty?

        # Calculate middle band (SMA)
        middle = SMA.calculate(data, period: period)

        # Calculate upper and lower bands
        upper = []
        lower = []

        data.each_with_index do |_, i|
          if i < period - 1
            upper << nil
            lower << nil
          else
            window = data[(i - period + 1)..i]
            mean = middle[i]
            variance = window.sum { |x| (x - mean)**2 } / period
            std = Math.sqrt(variance)

            upper << (mean + (std_dev * std))
            lower << (mean - (std_dev * std))
          end
        end

        {
          upper: upper,
          middle: middle,
          lower: lower
        }
      end
    end

    # Average True Range (ATR)
    #
    # Volatility indicator measuring market volatility.
    #
    # @example Calculate ATR
    #   ohlc = [
    #     { open: 100, high: 105, low: 98, close: 103 },
    #     { open: 103, high: 108, low: 101, close: 106 },
    #     ...
    #   ]
    #   atr = DhanHQ::Indicators::ATR.calculate(ohlc, period: 14)
    #
    class ATR
      # Calculate ATR for the given OHLC data.
      #
      # @param data [Array<Hash>] Array of OHLC hashes with :open, :high, :low, :close
      # @param period [Integer] Number of periods (default: 14)
      # @return [Array<Float>] ATR values (nil for insufficient data points)
      def self.calculate(data, period: 14)
        return [] if data.nil? || data.empty? || period < 1
        return [] if data.length < 2

        # Calculate true ranges
        true_ranges = data.each_cons(2).map do |prev, curr|
          high = curr[:high] || curr["high"]
          low = curr[:low] || curr["low"]
          prev_close = prev[:close] || prev["close"]

          [high - low, (high - prev_close).abs, (low - prev_close).abs].max
        end

        # Calculate ATR using smoothed average
        atr_values = [nil] # First value has no true range

        # First ATR is simple average
        if true_ranges.length >= period
          first_atr = true_ranges[0...period].sum.to_f / period
          atr_values.concat(Array.new(period - 1, nil))
          atr_values << first_atr

          # Subsequent ATRs use smoothing
          true_ranges[period..].each do |tr|
            previous_atr = atr_values.last
            atr_values << (((previous_atr * (period - 1)) + tr) / period)
          end
        else
          atr_values.concat(Array.new(true_ranges.length, nil))
        end

        atr_values
      end
    end
  end
end
