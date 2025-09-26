# frozen_string_literal: true

module DhanHQ
  module Models
    # Lightweight wrapper exposing market feed resources.
    class MarketFeed < BaseModel
      class << self
        # Fetches last traded price snapshots.
        #
        # @param params [Hash]
        # @return [Hash]
        def ltp(params)
          resource.ltp(params)
        end

        # Fetches OHLC data for the requested instruments.
        #
        # @param params [Hash]
        # @return [Hash]
        def ohlc(params)
          resource.ohlc(params)
        end

        # Fetches full quote depth and analytics.
        #
        # @param params [Hash]
        # @return [Hash]
        def quote(params)
          resource.quote(params)
        end

        # Shared market feed resource instance.
        #
        # @return [DhanHQ::Resources::MarketFeed]
        def resource
          @resource ||= DhanHQ::Resources::MarketFeed.new
        end
      end
    end
  end
end
