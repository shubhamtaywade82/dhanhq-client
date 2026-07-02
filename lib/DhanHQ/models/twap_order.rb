# frozen_string_literal: true

require_relative "../contracts/twap_order_contract"

module DhanHQ
  module Models
    ##
    # Model for creating and managing TWAP Orders.
    #
    # TWAP (Time-Weighted Average Price) orders split a large order into smaller
    # slices distributed evenly across a defined time window. This minimizes market
    # impact and achieves execution closer to the period's average price.
    #
    # @note **Static IP Whitelisting**: TWAP order creation, modification, and
    #   cancellation APIs require Static IP whitelisting.
    #
    # @example Create a TWAP order
    #   order = DhanHQ::Models::TwapOrder.create(
    #     dhan_client_id: "1000000003",
    #     transaction_type: "SELL",
    #     exchange_segment: "NSE_EQ",
    #     product_type: "INTRADAY",
    #     order_type: "MARKET",
    #     validity: "DAY",
    #     security_id: "11536",
    #     quantity: 500,
    #     price: 0,                    # MARKET order
    #     slice_interval: 300,         # 5 minutes
    #     start_time: "09:30:00",
    #     end_time: "15:00:00"
    #   )
    #   puts "TWAP Order ID: #{order.order_id} - #{order.order_status}"
    #
    # @example Modify a TWAP order (extend window)
    #   order = DhanHQ::Models::TwapOrder.find(order_id)
    #   order.modify(
    #     dhan_client_id: "1000000003",
    #     order_id: order_id,
    #     end_time: "15:30:00",
    #     slice_interval: 600
    #   )
    #
    # @example Cancel a TWAP order
    #   order = DhanHQ::Models::TwapOrder.find(order_id)
    #   order.cancel
    #
    class TwapOrder < BaseModel
      include Concerns::ApiResponseHandler

      attributes :dhan_client_id, :order_id, :correlation_id, :order_status,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :validity, :trading_symbol, :security_id, :quantity,
                 :remaining_quantity, :price, :trigger_price, :after_market_order,
                 :slice_interval, :start_time, :end_time, :leg_name,
                 :create_time, :update_time, :exchange_time, :drv_expiry_date,
                 :drv_option_type, :drv_strike_price,
                 :oms_error_code, :oms_error_description, :average_traded_price, :filled_qty

      class << self
        # @return [DhanHQ::Resources::TwapOrders]
        def resource
          @resource ||= DhanHQ::Resources::TwapOrders.new
        end

        # Retrieves all TWAP orders for the day.
        #
        # @return [Array<TwapOrder>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |o| new(o, skip_validation: true) }
        end

        # Retrieves a specific TWAP order by ID.
        #
        # @param order_id [String]
        # @return [TwapOrder, nil]
        def find(order_id)
          response = resource.find(order_id)
          return nil unless response.is_a?(Hash) && response.any?

          new(response, skip_validation: true)
        end

        # Creates a new TWAP order.
        #
        # @param params [Hash{Symbol => String, Integer, Float}]
        # @return [TwapOrder, nil]
        def create(params)
          normalized = snake_case(params)
          config = DhanHQ.configuration
          normalized[:dhan_client_id] ||= config.client_id if config&.client_id
          validate_params!(normalized, DhanHQ::Contracts::TwapOrderCreateContract)
          formatted = camelize_keys(normalized)
          response = resource.create(formatted)
          return nil unless response.is_a?(Hash) && response["orderId"]

          new(order_id: response["orderId"], order_status: response["orderStatus"], skip_validation: true)
        end
      end

      # Modifies an existing TWAP order.
      #
      # @param new_params [Hash{Symbol => String, Integer, Float}]
      # @return [TwapOrder, nil]
      def modify(new_params)
        raise "Order ID is required to modify a TWAP order" unless order_id

        DhanHQ.logger&.info("[DhanHQ::Models::TwapOrder] Modifying order #{order_id}")
        full_params = snake_case(new_params)
        config = DhanHQ.configuration
        full_params[:dhan_client_id] ||= config.client_id if config&.client_id
        full_params[:order_id] = order_id
        validate_params!(full_params, DhanHQ::Contracts::TwapOrderModifyContract)
        formatted = camelize_keys(full_params)
        response = self.class.resource.update(order_id, formatted)
        success = handle_api_response(response, success_key: "orderId",
                                                context: "[DhanHQ::Models::TwapOrder] Modification")
        return self.class.find(order_id) if success

        nil
      end

      # Cancels the TWAP order.
      #
      # @return [Boolean] true when cancelled successfully
      def cancel
        raise "Order ID is required to cancel a TWAP order" unless order_id

        response = self.class.resource.cancel(order_id)
        response.is_a?(Hash) && response["orderStatus"] == DhanHQ::Constants::OrderStatus::CANCELLED
      end
    end
  end
end
