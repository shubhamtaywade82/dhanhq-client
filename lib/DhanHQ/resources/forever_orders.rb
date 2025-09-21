# frozen_string_literal: true

module DhanHQ
  module Resources
    class ForeverOrders < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/forever"

      def all
        get("/orders")
      end

      def create(params)
        post("/orders", params: params)
      end

      def find(order_id)
        get("/orders/#{order_id}")
      end

      def update(order_id, params)
        put("/orders/#{order_id}", params: params)
      end

      def cancel(order_id)
        delete("/orders/#{order_id}")
      end
    end
  end
end
