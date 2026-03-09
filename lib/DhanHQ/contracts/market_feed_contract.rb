# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request payloads for Market Feed endpoints (LTP, OHLC, Quote).
    #
    # The Market Feed API expects a payload where keys are Exchange Segments
    # and values are Arrays of security IDs (Integers).
    #
    # @example Valid payload:
    #   {
    #     "NSE_EQ": [11536, 3456],
    #     "NSE_FNO": [49081, 49082]
    #   }
    #
    class MarketFeedContract < BaseContract
      params do
        config.validate_keys = true

        # Dynamically define all valid exchange segments as optional keys.
        # Each must be an array of integers.
        EXCHANGE_SEGMENTS.each do |segment|
          optional(segment.to_sym).array(:integer)
        end
      end

      rule do
        base.failure("must provide at least one exchange segment and security ID") if values.to_h.empty?

        total_instruments = 0
        values.to_h.each do |key, value|
          if value.is_a?(Array)
            key(key).failure("must not be empty") if value.empty?
            total_instruments += value.size
          end
        end

        if total_instruments > 1000
          base.failure("cannot fetch more than 1000 instruments in a single request (found #{total_instruments})")
        end
      end
    end
  end
end
