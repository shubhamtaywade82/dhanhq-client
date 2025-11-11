# frozen_string_literal: true

module DhanHQ
  module Resources
    ##
    # Resource for expired options data API endpoints
    class ExpiredOptionsData < BaseAPI
      API_TYPE = :data_api
      HTTP_PATH = "/v2/charts"

      ##
      # Fetch expired options data for rolling contracts
      # POST /charts/rollingoption
      #
      # @param params [Hash] Parameters for the request
      # @return [Hash] API response with expired options data
      def fetch(params)
        post("/rollingoption", params: params)
      end
    end
  end
end
