# frozen_string_literal: true

require "date"

module DhanHQ
  module Contracts
    # Validates request for POST /v2/data/marketmovers (ScanX ranked instruments).
    #
    # exchangeSegment, instrument[] (options / futures / equity kinds, no mixing
    # groups), category, limit (1-100). Expiry is required for options/futures;
    # universe is required for EQUITY and ignored otherwise.
    class MarketMoversContract < BaseContract
      DERIVATIVE_INSTRUMENTS = %w[OPTIDX OPTSTK OPTFUT FUTIDX FUTSTK FUTCOM].freeze
      private_constant :DERIVATIVE_INSTRUMENTS

      params do
        required(:exchange_segment).filled(:string, included_in?: Constants::ScanX::MARKET_MOVERS_SEGMENTS)
        required(:instrument).filled(:array, min_size?: 1) do
          each(:str?, included_in?: Constants::ScanX::MARKET_MOVERS_INSTRUMENTS)
        end
        required(:category).filled(:string, included_in?: Constants::ScanX::MARKET_MOVERS_CATEGORIES)
        required(:limit).filled(:integer, included_in?: 1..100)
        optional(:expiry).filled(:string)
        optional(:universe).filled(:string, included_in?: Constants::ScanX::MARKET_MOVERS_UNIVERSES)
      end

      rule(:expiry) do
        next unless value.is_a?(String)

        unless value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
          key.failure("must be in YYYY-MM-DD format")
          next
        end

        Date.parse(value)
      rescue StandardError
        key.failure("must be a valid date")
      end

      # Expiry is required when ranking derivatives; universe is required for EQUITY.
      rule(:instrument, :expiry) do
        instruments = Array(values[:instrument]).map(&:to_s)
        key(:expiry).failure("is required when instrument includes options or futures") if derivative?(instruments) && values[:expiry].to_s.empty?
      end

      rule(:instrument, :universe) do
        instruments = Array(values[:instrument]).map(&:to_s)
        key(:universe).failure("is required when instrument is EQUITY") if instruments.include?(Constants::InstrumentType::EQUITY) && values[:universe].to_s.empty?
      end

      # True when any requested instrument is an option or future.
      def derivative?(instruments)
        instruments.any? { |i| DERIVATIVE_INSTRUMENTS.include?(i) }
      end
    end
  end
end
