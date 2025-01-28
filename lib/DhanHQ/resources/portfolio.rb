# frozen_string_literal: true

module DhanHQ
  module Resources
    class Portfolio < BaseAPI
      HTTP_PATH = "/v2"
      # Retrieve list of holdings
      #
      # @return [Array<Hash>] The list of holdings
      def holdings
        get("/holdings")
      end

      # Retrieve list of positions
      #
      # @return [Array<Hash>] The list of open positions
      def positions
        get("/positions")
      end

      # Convert intraday position to delivery or vice versa
      #
      # @param params [Hash] Conversion parameters
      # @return [String] The API response status
      def convert_position(params)
        post("/positions/convert", params: params)
      end
    end
  end
end
