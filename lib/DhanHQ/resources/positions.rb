# frozen_string_literal: true

module DhanHQ
  module Resources
    class Positions < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/positions"

      ##
      # Fetch all open positions for the day.
      #
      # @return [Array<Hash>] API response containing position data.
      def all
        get("")
      end
    end
  end
end
