# frozen_string_literal: true

module DhanHQ
  module Resources
    class Orders < BaseAPI
      HTTP_PATH = "/v2/orders"

      # Place a new order
      #
      # @param params [Hash] Order parameters
      # @return [Hash] The API response
      def place_order(params)
        contract = DhanHQ::Contracts::PlaceOrderContract.new
        validation = contract.call(params)

        raise DhanHQ::Error, "Validation Error: #{validation.errors.to_h}" unless validation.success?

        post("", params: params)
      end

      # Modify a pending order
      #
      # @param order_id [String] Order ID
      # @param params [Hash] Modified order parameters
      # @return [Hash] The API response
      def modify_order(order_id, params)
        contract = DhanHQ::Contracts::ModifyOrderContract.new
        validation = contract.call(params)

        raise DhanHQ::Error, "Validation Error: #{validation.errors.to_h}" unless validation.success?

        put("/#{order_id}", params: params)
      end

      # Cancel a pending order
      #
      # @param order_id [String] Order ID
      # @return [Hash] The API response
      def cancel_order(order_id)
        delete("/#{order_id}")
      end

      # Slice an order into multiple legs
      #
      # @param params [Hash] Order slicing parameters
      # @return [Array<Hash>] The API response
      def slice_order(params)
        contract = DhanHQ::Contracts::SliceOrderContract.new
        validation = contract.call(params)

        raise DhanHQ::Error, "Validation Error: #{validation.errors.to_h}" unless validation.success?

        post("/slicing", params: params)
      end

      # Retrieve the list of all orders for the day
      #
      # @return [Array<Hash>] The API response
      def list_orders
        get
      end

      # Retrieve the status of an order by order ID
      #
      # @param order_id [String] Order ID
      # @return [Hash] The API response
      def get_order(order_id)
        get("/#{order_id}")
      end

      # Retrieve the status of an order by correlation ID
      #
      # @param correlation_id [String] Correlation ID
      # @return [Hash] The API response
      def get_order_by_correlation(correlation_id)
        get("/external/#{correlation_id}")
      end
    end
  end
end
