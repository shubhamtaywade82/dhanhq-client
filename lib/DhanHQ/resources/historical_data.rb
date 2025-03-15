# frozen_string_literal: true

module DhanHQ
  module Resources
    ##
    # Resource class for fetching Daily & Intraday historical data.
    # Based on the official docs:
    # - POST /v2/charts/historical  (daily timeframe)
    # - POST /v2/charts/intraday   (minute timeframe)
    #
    class HistoricalData < BaseAPI
      API_TYPE = :data_api     # Because we are fetching market data
      HTTP_PATH = "/v2/charts" # The base path for historical endpoints

      ##
      # POST /v2/charts/historical
      # "Daily Historical Data"
      # @param params [Hash]
      # @return [Hash] The parsed API response containing arrays of open, high, low, close, volume, timestamp
      def daily(params)
        post("/historical", params: params)
      end

      ##
      # POST /v2/charts/intraday
      # "Intraday Historical Data"
      # @param params [Hash]
      # @return [Hash] The parsed API response containing arrays for candle data
      def intraday(params)
        post("/intraday", params: params)
      end
    end
  end
end
