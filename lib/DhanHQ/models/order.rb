# frozen_string_literal: true

require_relative "../contracts/base_contract"

require_relative "../contracts/place_order_contract"
# require_relative "../contracts/modify_order_contract"
# require_relative "../contracts/slice_order_contract"
module DhanHQ
  module Models
    class Order < BaseResource
      attr_reader :order_id, :order_status

      # Define attributes that are part of an order
      attributes :correlation_id, :transaction_type, :exchange_segment,
                 :product_type, :order_type, :validity, :security_id, :quantity,
                 :disclosed_quantity, :price, :trigger_price, :order_flag, :price1,
                 :trigger_price1, :quantity1, :trading_symbol, :create_time,
                 :update_time, :exchange_time, :drv_expiry_date, :drv_option_type,
                 :drv_strike_price

      class << self
        # Fetch all orders for the day
        #
        # @return [Array<Order>]
        def all
          response = resource.list_orders

          return [] unless response.is_a?(Array)

          response.map { |order| new(order, skip_validation: true) }
        end

        # Fetch a specific order by order ID
        #
        # @param order_id [String]
        # @return [Order, nil]
        def find(order_id)
          response = resource.get_order(order_id)
          response.first ? new(response.first, skip_validation: true) : nil
        end

        # Fetch a specific order by correlation ID
        #
        # @param correlation_id [String]
        # @return [Order, nil]
        def find_by_correlation(correlation_id)
          response = resource.get_order_by_correlation(correlation_id)
          response[:status] == "success" ? new(response[:data]) : nil
        end

        # Place a new order
        #
        # @param params [Hash] Order parameters
        # @return [Order]
        def place(params)
          contract = DhanHQ::Contracts::PlaceOrderContract.new
          validation = contract.call(params)
          raise DhanHQ::Error, "Validation Error: #{validation.errors.to_h}" unless validation.success?

          response = resource.place_order(params)
          response[:status] == "success" ? new(response[:data]) : nil
        end

        # Access the API resource for orders
        #
        # @return [DhanHQ::Resources::Orders]
        def resource
          @resource ||= DhanHQ::Resources::Orders.new
        end
      end

      # Modify the order
      #
      # @param new_params [Hash]
      # @return [Order, nil]
      def modify(order_id, params)
        contract = DhanHQ::Contracts::ModifyOrderContract.new
        validation = contract.call(params)
        raise DhanHQ::Error, "Validation Error: #{validation.errors.to_h}" unless validation.success?

        response = resource.modify_order(order_id, params)
        response[:status] == "success" ? new(response[:data]) : nil
      end

      # Cancel the order
      #
      # @return [Boolean]
      def cancel
        raise "Order ID is required to cancel an order" unless id

        response = self.class.resource.cancel_order(id)
        response[:status] == "success"
      end

      # Fetch the latest details of the order
      #
      # @return [Order, nil]
      def refresh
        raise "Order ID is required to refresh an order" unless id

        self.class.find(id)
      end

      private

      # Validation contract for order placement
      #
      # @return [DhanHQ::Contracts::PlaceOrderContract]
      def validation_contract
        DhanHQ::Contracts::PlaceOrderContract.new
      end
    end
  end
end
