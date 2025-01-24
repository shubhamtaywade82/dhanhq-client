# frozen_string_literal: true

module DhanHQ
  module Resources
    class Orders < BaseAPI
      # Place an order
      def place(params)
        post("", params: params)
      end

      # Fetch details of an order by ID
      def fetch(order_id)
        get("/#{order_id}")
      end

      # Cancel an order by ID
      def cancel(order_id)
        delete("/#{order_id}")
      end

      # Modify an order by ID
      def modify(order_id, params)
        put("/#{order_id}", params: params)
      end

      # Fetch all orders for the day
      def fetch_all
        get
      end
    end
  end
end
