# frozen_string_literal: true

module DhanHQ
  module Resources
    class Funds < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/fundlimit"

      ##
      # Fetch fund limit details.
      #
      # @return [Hash] API response containing fund details.
      def fetch
        get("")
      end
    end
  end
end
