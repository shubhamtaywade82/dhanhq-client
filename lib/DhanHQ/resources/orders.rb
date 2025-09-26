# frozen_string_literal: true

module DhanHQ
  # REST API wrappers grouped by resource type.
  module Resources
    # Resource client for managing equity and F&O orders.
    class Orders < BaseAPI
      # Orders are routed through the trading API tier.
      API_TYPE = :order_api
      # Base path for order endpoints.
      HTTP_PATH = "/v2/orders"

      # Retrieve all orders for the current trading day.
      #
      # @return [Array<Hash>]
      def all
        get("")
      end

      # Places a new order using the provided payload.
      #
      # @param params [Hash]
      # @return [Hash]
      def create(params)
        post("", params: params)
      end

      # Fetches a single order by broker order id.
      #
      # @param order_id [String]
      # @return [Hash]
      def find(order_id)
        get("/#{order_id}")
      end

      # Modifies an existing order.
      #
      # @param order_id [String]
      # @param params [Hash]
      # @return [Hash]
      def update(order_id, params)
        put("/#{order_id}", params: params)
      end

      # Cancels an existing order.
      #
      # @param order_id [String]
      # @return [Hash]
      def cancel(order_id)
        delete("/#{order_id}")
      end

      # Places a slicing order request.
      #
      # @param params [Hash]
      # @return [Hash]
      def slicing(params)
        post("/slicing", params: params)
      end

      # Retrieve an order by client-supplied correlation id.
      #
      # @param correlation_id [String]
      # @return [Hash]
      def by_correlation(correlation_id)
        get("/external/#{correlation_id}")
      end
    end
  end
end
