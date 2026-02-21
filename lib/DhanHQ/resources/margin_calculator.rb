# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for invoking the margin calculator endpoint.
    class MarginCalculator < BaseAPI
      # Calculator results are served via the trading API.
      API_TYPE = :order_api
      # Base path for the calculator endpoint.
      HTTP_PATH = "/v2/margincalculator"

      ##
      # Calculate margin requirements for an order.
      #
      # @param params [Hash] Request parameters for margin calculation.
      # @return [Hash] API response containing margin details.
      def calculate(params)
        post("", params: params)
      end

      ##
      # Calculate margin requirements for multiple scripts in one request.
      #
      # @param params [Hash] Request parameters including scripList, includePosition, includeOrder.
      # @return [Hash] API response containing combined margin details with hedge benefit.
      def calculate_multi(params)
        post("/multi", params: params)
      end
    end
  end
end
