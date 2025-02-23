# frozen_string_literal: true

module DhanHQ
  module Resources
    class Holdings < BaseAPI
      API_TYPE = :order_api
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
