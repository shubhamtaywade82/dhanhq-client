# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for GTT/forever order management.
    class ForeverOrders < BaseAPI
      # Uses the trading API tier.
      API_TYPE = :order_api
      # Root path for forever order operations.
      HTTP_PATH = "/v2/forever"

      # Lists all forever orders for the account.
      #
      # @return [Array<Hash>]
      def all
        get("/orders")
      end

      # Creates a new forever order configuration.
      #
      # @param params [Hash]
      # @return [Hash]
      def create(params)
        post("/orders", params: params)
      end

      # Fetches a forever order by identifier.
      #
      # @param order_id [String]
      # @return [Hash]
      def find(order_id)
        get("/orders/#{order_id}")
      end

      # Updates a forever order.
      #
      # @param order_id [String]
      # @param params [Hash]
      # @return [Hash]
      def update(order_id, params)
        put("/orders/#{order_id}", params: params)
      end

      # Cancels a forever order.
      #
      # @param order_id [String]
      # @return [Hash]
      def cancel(order_id)
        delete("/orders/#{order_id}")
      end
    end
  end
end
