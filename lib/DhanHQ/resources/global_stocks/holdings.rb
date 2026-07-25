# frozen_string_literal: true

module DhanHQ
  module Resources
    module GlobalStocks
      # Resource client for Global Stocks holdings.
      #
      #   GET /v2/globalstocks/holdings
      class Holdings < BaseAPI
        API_TYPE = :order_api
        HTTP_PATH = "/v2/globalstocks/holdings"

        # Retrieves the authenticated user's US stock holdings.
        #
        # @return [Array<Hash>]
        def all
          get("")
        end
      end
    end
  end
end
