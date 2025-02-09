# frozen_string_literal: true

module DhanHQ
  module Resources
    class MarketQuote < BaseAPI
      HTTP_PATH = "/v2/marketfeed"
      # Fetch ticker data (LTP) for instruments
      #
      # @param params [Hash] Instruments and their exchange segments
      # @return [Hash] The API response with ticker data
      def fetch_ticker_data(params)
        post("/ltp", params: params)
      end

      # Fetch OHLC data for instruments
      #
      # @param params [Hash] Instruments and their exchange segments
      # @return [Hash] The API response with OHLC data
      def fetch_ohlc_data(params)
        post("/ohlc", params: params)
      end

      # Fetch market depth data for instruments
      #
      # @param params [Hash] Instruments and their exchange segments
      # @return [Hash] The API response with market depth data
      def fetch_market_depth(params)
        post("/quote", params: params)
      end
    end
  end
end
