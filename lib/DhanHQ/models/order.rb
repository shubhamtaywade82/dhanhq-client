# frozen_string_literal: true

require_relative "../contracts/order_contract"
require_relative "../resources/orders"

module DhanHQ
  module Models
    class Order < BaseResource
      attr_accessor :order_id, :status, :quantity, :price, :transaction_type,
                    :exchange_segment, :product_type, :trigger_price, :validity

      class << self
        # Delegate the creation to the resource
        def place(params)
          response = resource.create(params)
          build_from_response(response)
        end

        # Delegate API operations to the resource
        def resource
          @resource ||= DhanHQ::Resources::Orders.new
        end
      end

      # Cancel the order
      def cancel
        raise "Order ID is required to cancel an order" unless id

        response = self.class.resource.delete("/#{id}")
        response[:status] == "success"
      end

      # Modify the order
      def modify(new_params)
        raise "Order ID is required to modify an order" unless id

        response = self.class.resource.put("/#{id}", params: new_params)
        self.class.build_from_response(response)
      end

      # Fetch the latest details of the order
      def fetch_details
        raise "Order ID is required to fetch details" unless id

        response = self.class.resource.get("/#{id}")
        self.class.build_from_response(response)
      end

      private

      # Validation contract for Order
      def validation_contract
        DhanHQ::Validation::OrderContract
      end
    end
  end
end
