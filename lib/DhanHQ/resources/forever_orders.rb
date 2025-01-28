# frozen_string_literal: true

module DhanHQ
  module Resources
    class ForeverOrders < BaseAPI
      HTTP_PATH = "/v2/forever/orders"

      # Create a new Forever Order
      #
      # @param params [Hash] Order parameters
      # @return [Hash] The API response
      def create(params)
        post("", params: params)
      end

      # Modify an existing Forever Order
      #
      # @param order_id [String] Order ID
      # @param params [Hash] Modified order parameters
      # @return [Hash] The API response
      def modify(order_id, params)
        put("/#{order_id}", params: params)
      end

      # Cancel an existing Forever Order
      #
      # @param order_id [String] Order ID
      # @return [Hash] The API response
      def cancel(order_id)
        delete("/#{order_id}")
      end

      # Retrieve all Forever Orders
      #
      # @return [Array<Hash>] The API response
      def list
        get
      end
    end
  end
end
