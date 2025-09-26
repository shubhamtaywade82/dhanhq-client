# frozen_string_literal: true

module DhanHQ
  module Resources
    # Provides access to current day trades endpoints
    class Trades < BaseAPI
      # Trade history is fetched from the trading API tier.
      API_TYPE = :order_api
      # Base path for trade retrieval.
      HTTP_PATH = "/v2/trades"

      # GET /v2/trades
      def all
        get("")
      end

      # GET /v2/trades/{order-id}
      def find(order_id)
        get("/#{order_id}")
      end
    end
  end
end
