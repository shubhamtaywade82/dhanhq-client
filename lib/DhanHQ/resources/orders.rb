# frozen_string_literal: true

module DhanHQ
  module Resources
    class Orders < BaseResource
      API_TYPE = :order_api
      HTTP_PATH = "/v2/orders"

      # Place a new order
      def place_order(params)
        post("", params: params)
      end

      # Get an order by order ID
      def get_order(order_id)
        get("/#{order_id}")
      end

      # Modify an order
      def modify_order(order_id, params)
        put("/#{order_id}", params: params)
      end

      # Cancel an order
      def cancel_order(order_id)
        delete("/#{order_id}")
      end

      # Retrieve orders for the day
      def list_orders
        get("")
      end

      # Retrieve order by correlation id
      def order_by_correlation(correlation_id)
        get("/external/#{correlation_id}")
      end
    end
  end
end
