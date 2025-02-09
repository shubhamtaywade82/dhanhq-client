# frozen_string_literal: true

module DhanHQ
  module Resources
    class HistoricalData < BaseAPI
      HTTP_PATH = "/v2/charts"

      # Fetch daily historical data (OHLC)
      #
      # @param params [Hash] Parameters for the daily historical data request
      # @return [Hash] The API response with OHLC data
      def fetch_daily_data(params)
        post("/historical", params: params)
      end

      # Fetch intraday historical data (OHLC)
      #
      # @param params [Hash] Parameters for the intraday historical data request
      # @return [Hash] The API response with OHLC data
      def fetch_intraday_data(params)
        post("/intraday", params: params)
      end
    end
  end
end
