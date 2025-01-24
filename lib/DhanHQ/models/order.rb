# frozen_string_literal: true

require_relative "../contracts/order_contract"
require_relative "../resources/orders"

module DhanHQ
  module Models
    class Order < BaseResource
      attr_accessor :order_id, :status, :quantity, :price, :transaction_type,
                    :exchange_segment, :product_type, :trigger_price, :validity

      # Place the order
      def place
        raise "Validation failed: #{errors}" unless valid?

        response = api_client.place(to_request_params)
        self.class.build_from_response(response)
      rescue StandardError => e
        DhanHQ::ErrorHandler.handle(e)
      end

      # Cancel the order
      def cancel
        raise "Order ID is required to cancel an order" unless order_id

        response = api_client.cancel(order_id)
        self.class.build_from_response(response)
      rescue StandardError => e
        DhanHQ::ErrorHandler.handle(e)
      end

      # Modify the order
      def modify(new_params)
        raise "Order ID is required to modify an order" unless order_id

        response = api_client.modify(order_id, camelize_keys(new_params))
        self.class.build_from_response(response)
      rescue StandardError => e
        DhanHQ::ErrorHandler.handle(e)
      end

      # Fetch the latest details of the order
      def fetch_details
        raise "Order ID is required to fetch details" unless order_id

        response = api_client.fetch(order_id)
        self.class.build_from_response(response)
      rescue StandardError => e
        DhanHQ::ErrorHandler.handle(e)
      end

      private

      # API client instance for Orders API
      def api_client
        @api_client ||= DhanHQ::Resources::Orders.new
      end

      # Validation contract for the Order model
      def validation_contract
        DhanHQ::Contracts::OrderContract.new
      end
    end
  end
end
