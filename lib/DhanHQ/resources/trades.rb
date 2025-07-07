module DhanHQ
  module Resources
    # Provides access to current day trades endpoints
    class Trades < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/trades".freeze

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
