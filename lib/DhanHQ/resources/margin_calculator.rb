# frozen_string_literal: true

module DhanHQ
  module Resources
    class MarginCalculator < BaseResource
      API_TYPE = :order_api
      HTTP_PATH = "/v2/margincalculator"

      ##
      # Calculate margin requirements for an order.
      #
      # @param params [Hash] Request parameters for margin calculation.
      # @return [Hash] API response containing margin details.
      def calculate(params)
        post("", params: params)
      end
    end
  end
end
