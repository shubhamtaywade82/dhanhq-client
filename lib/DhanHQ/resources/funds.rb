# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client that exposes funds and limits endpoints.
    class Funds < BaseAPI
      # Funds data comes from the trading API tier.
      API_TYPE = :order_api
      # Base path for fund limit endpoints.
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
