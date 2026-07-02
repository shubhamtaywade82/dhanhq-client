# frozen_string_literal: true

module DhanHQ
  module MarketData
    # A time series of OHLCV candles for a single instrument.
    #
    # Wraps historical data responses into a convenient array-like structure
    # with helper methods for analysis.
    #
    # @example Build a series from historical data response
    #   response = DhanHQ::Models::HistoricalData.daily(
    #     security_id: "11536",
    #     exchange_segment: "NSE_EQ",
    #     instrument: "EQUITY",
    #     from_date: "2024-01-01",
    #     to_date: "2024-12-31"
    #   )
    #   series = DhanHQ::MarketData::OHLCSeries.from_response(response)
    #   series.closes #=> [2800.0, 2810.5, ...]
    #   series.volumes #=> [123456, 234567, ...]
    #
    class OHLCSeries
      include Enumerable

      Candle = Struct.new(:timestamp, :open, :high, :low, :close, :volume, :open_interest) do
        def body_size
          (close - open).abs
        end

        def upper_shadow
          high - [open, close].max
        end

        def lower_shadow
          [open, close].min - low
        end

        def bullish?
          close > open
        end

        def bearish?
          close < open
        end

        def doji?
          (close - open).abs < (high - low) * 0.1
        end
      end

      attr_reader :candles, :security_id, :exchange_segment

      def initialize(candles = [], metadata = {})
        @candles = candles
        @security_id = metadata[:security_id]
        @exchange_segment = metadata[:exchange_segment]
      end

      # Build an OHLCSeries from a raw historical data API response.
      def self.from_response(response)
        data = response.is_a?(Hash) ? (response[:data] || response["data"] || response) : response
        data = [data] unless data.is_a?(Array)

        candles = data.map do |candle|
          Candle.new(
            timestamp: candle[:timestamp] || candle["timestamp"],
            open: (candle[:open] || candle["open"]).to_f,
            high: (candle[:high] || candle["high"]).to_f,
            low: (candle[:low] || candle["low"]).to_f,
            close: (candle[:close] || candle["close"]).to_f,
            volume: (candle[:volume] || candle["volume"]).to_i,
            open_interest: candle[:open_interest] || candle["open_interest"]
          )
        end

        new(candles)
      end

      def each(&)
        @candles.each(&)
      end

      def size
        @candles.size
      end

      def empty?
        @candles.empty?
      end

      # Get all close prices.
      def closes
        @candles.map(&:close)
      end

      # Get all open prices.
      def opens
        @candles.map(&:open)
      end

      # Get all high prices.
      def highs
        @candles.map(&:high)
      end

      # Get all low prices.
      def lows
        @candles.map(&:low)
      end

      # Get all volumes.
      def volumes
        @candles.map(&:volume)
      end

      # Get the most recent candle.
      def last
        @candles.last
      end

      # Get the oldest candle.
      def first
        @candles.first
      end

      # Get the date range of the series.
      def date_range
        return nil if empty?

        [first.timestamp, last.timestamp]
      end

      # Calculate the total volume across all candles.
      def total_volume
        @candles.sum(&:volume)
      end

      # Calculate the average close price.
      def average_close
        return nil if empty?

        closes.sum / size
      end

      # Calculate the price range (highest high - lowest low).
      def price_range
        return nil if empty?

        highs.max - lows.min
      end

      # Slice the series by date range (requires timestamps).
      def slice_range(from_timestamp, to_timestamp)
        self.class.new(
          @candles.select { |c| c.timestamp.between?(from_timestamp, to_timestamp) },
          { security_id: @security_id, exchange_segment: @exchange_segment }
        )
      end

      # Take the last N candles.
      def tail(count)
        self.class.new(
          @candles.last(count),
          { security_id: @security_id, exchange_segment: @exchange_segment }
        )
      end
    end
  end
end
