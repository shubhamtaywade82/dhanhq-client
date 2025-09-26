# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client managing intraday and carry-forward positions.
    class Positions < BaseAPI
      # Position endpoints are exposed via the trading API.
      API_TYPE = :order_api
      # Base path for position management endpoints.
      HTTP_PATH = "/v2/positions"

      ##
      # Fetch all open positions for the day.
      #
      # @return [Array<Hash>] API response containing position data.
      def all
        get("")
      end

      # Converts a position between eligible product types.
      #
      # @param params [Hash]
      # @return [Hash]
      def convert(params)
        post("/convert", params: params)
      end
    end
  end
end
