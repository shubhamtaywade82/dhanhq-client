# frozen_string_literal: true

require_relative "../contracts/place_order_contract"
require_relative "../contracts/modify_order_contract"

module DhanHQ
  module Models
    class Order < BaseModel
      attr_reader :order_id, :order_status

      # Define attributes that are part of an order
      attributes :dhan_client_id, :order_id, :correlation_id, :order_status,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :validity, :trading_symbol, :security_id, :quantity,
                 :disclosed_quantity, :price, :trigger_price, :after_market_order,
                 :bo_profit_value, :bo_stop_loss_value, :leg_name, :create_time,
                 :update_time, :exchange_time, :drv_expiry_date, :drv_option_type,
                 :drv_strike_price, :oms_error_code, :oms_error_description, :algo_id,
                 :remaining_quantity, :average_traded_price, :filled_qty

      class << self
        # Fetch all orders for the day
        #
        # @return [Array<Order>]
        def all
          response = resource.list_orders
          return [] unless response.is_a?(Array)

          response.map { |order| new(order, skip_validation: true) }
        end

        # Fetch a specific order by ID
        #
        # @param order_id [String]
        # @return [Order, nil]
        def find(order_id)
          response = resource.get_order(order_id)
          return nil unless response.is_a?(Hash) && response.any?

          new(response, skip_validation: true)
        end

        # Fetch a specific order by correlation ID
        #
        # @param correlation_id [String]
        # @return [Order, nil]
        def find_by_correlation(correlation_id)
          response = resource.get_order_by_correlation(correlation_id)
          return nil unless response[:status] == "success"

          new(response[:data], skip_validation: true)
        end

        # Place a new order
        #
        # @param params [Hash] Order parameters
        # @return [Order]
        def place(params)
          validate_params!(params, DhanHQ::Contracts::PlaceOrderContract)

          response = resource.place_order(params)
          return nil unless response.is_a?(Hash) && response["orderId"]

          # Fetch the complete order details
          find(response["orderId"])
        end

        # Access the API resource for orders
        #
        # @return [DhanHQ::Resources::Orders]
        def resource
          @resource ||= DhanHQ::Resources::Orders.new
        end
      end

      # Modify the order while preserving existing attributes
      #
      # @param new_params [Hash]
      # @return [Order, nil]
      def modify(new_params)
        raise "Order ID is required to modify an order" unless id

        # Merge current order attributes with new parameters
        updated_params = attributes.merge(new_params)

        # Validate with ModifyOrderContract
        validate_params!(updated_params, DhanHQ::Contracts::ModifyOrderContract)

        response = self.class.resource.modify_order(id, updated_params)

        # Fetch the latest order details
        return self.class.find(id) if response[:orderStatus] == "TRANSIT"

        nil
      end

      # Cancel the order
      #
      # @return [Boolean]
      def cancel
        raise "Order ID is required to cancel an order" unless id

        response = self.class.resource.cancel_order(id)
        response["orderStatus"] == "CANCELLED"
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
