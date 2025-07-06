# frozen_string_literal: true

module DhanHQ
  module Resources
    class SuperOrders < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/super/orders"

      def all
        get("")
      end

      def create(params)
        post("", params: params)
      end

      def update(order_id, params)
        put("/#{order_id}", params: params)
      end

      def cancel(order_id, leg_name)
        delete("/#{order_id}/#{leg_name}")
      end
    end
  end
end
