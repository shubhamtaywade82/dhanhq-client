# frozen_string_literal: true

module DhanHQ
  # Higher-level abstractions for market data consumption.
  module MarketData
    # A snapshot of market data for multiple instruments at a point in time.
    #
    # Wraps the raw MarketFeed response into a more convenient structure
    # with typed accessors and helper methods.
    #
    # @example Build a snapshot from MarketFeed response
    #   response = DhanHQ::Models::MarketFeed.ltp("NSE_EQ" => [11536, 3456])
    #   snapshot = DhanHQ::MarketData::MarketSnapshot.from_response(response)
    #   snapshot.ltp("NSE_EQ", "11536") #=> 2850.50
    #
    class MarketSnapshot
      attr_reader :data, :fetched_at

      def initialize(data = {})
        @data = data
        @fetched_at = Time.now
      end

      # Build a MarketSnapshot from a raw MarketFeed API response.
      def self.from_response(response)
        raw_data = response.is_a?(Hash) ? (response[:data] || response["data"] || {}) : {}
        new(normalize_data(raw_data))
      end

      # Get LTP for a specific instrument.
      def ltp(exchange_segment, security_id)
        instrument_data(exchange_segment, security_id)&.dig(:last_price)
      end

      # Get OHLC for a specific instrument.
      def ohlc(exchange_segment, security_id)
        instrument_data(exchange_segment, security_id)&.dig(:ohlc)
      end

      # Get full quote (market depth) for a specific instrument.
      def quote(exchange_segment, security_id)
        instrument_data(exchange_segment, security_id)
      end

      # Get all instruments for a specific exchange segment.
      def for_segment(exchange_segment)
        @data[exchange_segment.to_s] || {}
      end

      # Get all security IDs across all segments.
      def security_ids
        @data.each_with_object([]) do |(_segment, instruments), ids|
          ids.concat(instruments.keys)
        end
      end

      # Get total number of instruments in the snapshot.
      def size
        @data.values.sum(&:size)
      end

      # Check if the snapshot is empty.
      def empty?
        @data.empty? || @data.values.all?(&:empty?)
      end

      private

      def instrument_data(exchange_segment, security_id)
        @data[exchange_segment.to_s]&.dig(security_id.to_s)
      end

      def self.normalize_data(data)
        result = {}
        data.each do |segment, instruments|
          result[segment.to_s] = {}
          next unless instruments.is_a?(Hash)

          instruments.each do |sec_id, info|
            result[segment.to_s][sec_id.to_s] = normalize_instrument(info)
          end
        end
        result
      end
      private_class_method :normalize_data

      def self.normalize_instrument(info)
        return info unless info.is_a?(Hash)

        info.each_with_object({}) do |(key, value), hash|
          hash[key.to_sym] = value
        end
      end
      private_class_method :normalize_instrument
    end
  end
end
