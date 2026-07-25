# frozen_string_literal: true

module DhanHQ
  module Resources
    module GlobalStocks
      # Resource client for the Global Stocks trade book.
      #
      #   GET /v2/globalstocks/trades
      #   GET /v2/globalstocks/trades/{security-id}
      class Trades < BaseAPI
        API_TYPE = :order_api
        HTTP_PATH = "/v2/globalstocks/trades"

        # Retrieves the current trading day's executed Global Stocks trades.
        #
        # @return [Array<Hash>]
        def all
          get("")
        end

        # Retrieves executed Global Stocks trades for a single security.
        #
        # @param security_id [String]
        # @return [Array<Hash>]
        def by_security_id(security_id)
          get("/#{security_id}")
        end
      end
    end
  end
end
