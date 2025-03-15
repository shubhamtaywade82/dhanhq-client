# frozen_string_literal: true

module DhanHQ
  module Resources
    class Orders < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/orders"

      # Retrieve orders for the day
      def all
        get("")
      end

      def create(params)
        post("", params: params)
      end

      def find(order_id)
        get("/#{order_id}")
      end

      def update(order_id, params)
        put("/#{order_id}", params: params)
      end

      def cancel(order_id)
        delete("/#{order_id}")
      end

      def slicing(params)
        post("/slicing", params: params)
      end

      # Retrieve order by correlation id
      def by_correlation(correlation_id)
        get("/external/#{correlation_id}")
      end
    end
  end
end
