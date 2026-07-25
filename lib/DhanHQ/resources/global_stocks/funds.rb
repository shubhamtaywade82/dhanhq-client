# frozen_string_literal: true

module DhanHQ
  module Resources
    module GlobalStocks
      # Resource client for the Global Stocks fund limit.
      #
      #   GET /v2/globalstocks/fundlimit
      #
      # Global Stocks funds are held in USD and are reported separately from the
      # domestic INR fund limit exposed by {DhanHQ::Resources::Funds}.
      class Funds < BaseAPI
        API_TYPE = :order_api
        HTTP_PATH = "/v2/globalstocks/fundlimit"

        # Retrieves the authenticated user's US stock fund limit details.
        #
        # @return [Hash]
        def fetch
          get("")
        end
      end
    end
  end
end
