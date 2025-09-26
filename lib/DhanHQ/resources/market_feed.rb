# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for fetching on-demand market data snapshots.
    class MarketFeed < BaseAPI
      # Market feed requests hit the data API tier.
      API_TYPE = :data_api
      # Root path for market feed endpoints.
      HTTP_PATH = "/v2"

      ##
      # POST /v2/marketfeed/ltp
      # Returns the LTP (Last Traded Price) of up to 1000 instruments.
      #
      # @param params [Hash] Example:
      #   {
      #     "NSE_EQ": [11536, 3456],
      #     "NSE_FNO": [49081, 49082]
      #   }
      # @return [HashWithIndifferentAccess]
      def ltp(params)
        post("/marketfeed/ltp", params: params)
      end

      ##
      # POST /v2/marketfeed/ohlc
      # Returns open-high-low-close for up to 1000 instruments.
      #
      # @param params [Hash]
      # @return [HashWithIndifferentAccess]
      def ohlc(params)
        post("/marketfeed/ohlc", params: params)
      end

      ##
      # POST /v2/marketfeed/quote
      # Returns market depth, OI, and other details for up to 1000 instruments.
      #
      # @param params [Hash]
      # @return [HashWithIndifferentAccess]
      def quote(params)
        quote_resource.post("/marketfeed/quote", params: params)
      end

      private

      # Lazily builds a `:quote_api` scoped client for quote depth requests.
      #
      # @return [MarketFeed]
      def quote_resource
        @quote_resource ||= self.class.new(api_type: :quote_api)
      end
    end
  end
end
