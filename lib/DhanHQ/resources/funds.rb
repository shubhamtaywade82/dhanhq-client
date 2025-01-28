# frozen_string_literal: true

module DhanHQ
  module Resources
    class Funds < BaseAPI
      HTTP_PATH = "/v2"
      # Calculate margin requirements for an order
      #
      # @param params [Hash] Margin calculation parameters
      # @return [Hash] The API response with margin details
      def margin_calculator(params)
        post("/margincalculator", params: params)
      end

      # Retrieve fund limits for the trading account
      #
      # @return [Hash] The API response with fund details
      def fund_limit
        get("/fundlimit")
      end
    end
  end
end
