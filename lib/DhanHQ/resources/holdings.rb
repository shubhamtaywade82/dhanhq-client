# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client exposing portfolio holdings.
    class Holdings < BaseAPI
      # Holdings are exposed via the trading API.
      API_TYPE = :order_api
      # Base path for holdings queries.
      HTTP_PATH = "/v2/holdings"

      ##
      # Fetch all holdings.
      #
      # @return [Array<Hash>] API response containing holdings data.
      def all
        get("")
      end
    end
  end
end
