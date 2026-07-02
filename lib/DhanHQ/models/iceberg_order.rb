# frozen_string_literal: true

require_relative "../contracts/iceberg_order_contract"

module DhanHQ
  module Models
    ##
    # Model for creating and managing Iceberg Orders.
    #
    # Iceberg orders allow you to place a large order while revealing only a small
    # "visible" portion (disclosed quantity) to the market at a time. The remaining
    # quantity is hidden and filled as prior legs execute, reducing market impact
    # and information leakage.
    #
    # @note **Static IP Whitelisting**: Iceberg order creation, modification, and
    #   cancellation APIs require Static IP whitelisting.
    #
    # @example Create an iceberg order
    #   order = DhanHQ::Models::IcebergOrder.create(
    #     dhan_client_id: "1000000003",
    #     transaction_type: "BUY",
    #     exchange_segment: "NSE_EQ",
    #     product_type: "INTRADAY",
    #     order_type: "LIMIT",
    #     validity: "DAY",
    #     security_id: "11536",
    #     quantity: 1000,
    #     price: 2450.50,
    #     iceberg_qty: 100,
    #     disclosed_quantity: 100
    #   )
    #   puts "Iceberg Order ID: #{order.order_id} - #{order.order_status}"
    #
    # @example Modify an iceberg order (change visible leg size)
    #   order = DhanHQ::Models::IcebergOrder.find(order_id)
    #   order.modify(
    #     dhan_client_id: "1000000003",
    #     order_id: order_id,
    #     price: 2440.0,
    #     iceberg_qty: 150
    #   )
    #
    # @example Cancel an iceberg order
    #   order = DhanHQ::Models::IcebergOrder.find(order_id)
    #   order.cancel
    #
    # @example List all iceberg orders for the day
    #   orders = DhanHQ::Models::IcebergOrder.all
    #
    class IcebergOrder < BaseModel
      include Concerns::ApiResponseHandler

      attributes :dhan_client_id, :order_id, :correlation_id, :order_status,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :validity, :trading_symbol, :security_id, :quantity,
                 :remaining_quantity, :price, :trigger_price, :after_market_order,
                 :iceberg_qty, :disclosed_quantity, :leg_name,
                 :create_time, :update_time, :exchange_time, :drv_expiry_date,
                 :drv_option_type, :drv_strike_price,
                 :oms_error_code, :oms_error_description, :average_traded_price, :filled_qty

      class << self
        # @return [DhanHQ::Resources::IcebergOrders]
        def resource
          @resource ||= DhanHQ::Resources::IcebergOrders.new
        end

        # Retrieves all iceberg orders for the day.
        #
        # @return [Array<IcebergOrder>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |o| new(o, skip_validation: true) }
        end

        # Retrieves a specific iceberg order by ID.
        #
        # @param order_id [String]
        # @return [IcebergOrder, nil]
        def find(order_id)
          response = resource.find(order_id)
          return nil unless response.is_a?(Hash) && response.any?

          new(response, skip_validation: true)
        end

        # Creates a new iceberg order.
        #
        # @param params [Hash{Symbol => String, Integer, Float}]
        # @return [IcebergOrder, nil]
        def create(params)
          normalized = snake_case(params)
          config = DhanHQ.configuration
          normalized[:dhan_client_id] ||= config.client_id if config&.client_id
          validate_params!(normalized, DhanHQ::Contracts::IcebergOrderCreateContract)
          formatted = camelize_keys(normalized)
          response = resource.create(formatted)
          return nil unless response.is_a?(Hash) && response["orderId"]

          new(order_id: response["orderId"], order_status: response["orderStatus"], skip_validation: true)
        end
      end

      # Modifies an existing iceberg order.
      #
      # @param new_params [Hash{Symbol => String, Integer, Float}]
      # @return [IcebergOrder, nil]
      def modify(new_params)
        raise "Order ID is required to modify an iceberg order" unless order_id

        DhanHQ.logger&.info("[DhanHQ::Models::IcebergOrder] Modifying order #{order_id}")
        full_params = snake_case(new_params)
        config = DhanHQ.configuration
        full_params[:dhan_client_id] ||= config.client_id if config&.client_id
        full_params[:order_id] = order_id
        validate_params!(full_params, DhanHQ::Contracts::IcebergOrderModifyContract)
        formatted = camelize_keys(full_params)
        response = self.class.resource.update(order_id, formatted)
        success = handle_api_response(response, success_key: "orderId",
                                                context: "[DhanHQ::Models::IcebergOrder] Modification")
        return self.class.find(order_id) if success

        nil
      end

      # Cancels the iceberg order.
      #
      # @return [Boolean] true when cancelled successfully
      def cancel
        raise "Order ID is required to cancel an iceberg order" unless order_id

        response = self.class.resource.cancel(order_id)
        response.is_a?(Hash) && response["orderStatus"] == DhanHQ::Constants::OrderStatus::CANCELLED
      end
    end
  end
end
