# frozen_string_literal: true

module DhanHQ
  module Models
    # Model wrapping multi-leg super order payloads.
    class SuperOrder < BaseModel
      attributes :dhan_client_id, :order_id, :correlation_id, :order_status,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :validity, :trading_symbol, :security_id, :quantity,
                 :remaining_quantity, :ltp, :price, :after_market_order,
                 :leg_name, :exchange_order_id, :create_time, :update_time,
                 :exchange_time, :oms_error_description, :average_traded_price,
                 :filled_qty, :leg_details, :target_price, :stop_loss_price,
                 :trailing_jump

      class << self
        # Shared resource instance used for API calls.
        #
        # @return [DhanHQ::Resources::SuperOrders]
        def resource
          @resource ||= DhanHQ::Resources::SuperOrders.new
        end

        # Fetches all configured super orders.
        #
        # @return [Array<SuperOrder>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |o| new(o, skip_validation: true) }
        end

        # Creates a new super order with the provided legs.
        #
        # @param params [Hash]
        # @return [SuperOrder, nil]
        def create(params)
          response = resource.create(params)
          return nil unless response.is_a?(Hash) && response["orderId"]

          new(order_id: response["orderId"], order_status: response["orderStatus"], skip_validation: true)
        end
      end

      # Updates the order legs for an existing super order.
      #
      # @param new_params [Hash]
      # @return [Boolean]
      def modify(new_params)
        raise "Order ID is required to modify a super order" unless id

        response = self.class.resource.update(id, new_params)
        response["orderId"] == id
      end

      # Cancels a specific leg (or the entry leg by default).
      #
      # @param leg_name [String]
      # @return [Boolean]
      def cancel(leg_name = "ENTRY_LEG")
        raise "Order ID is required to cancel a super order" unless id

        response = self.class.resource.cancel(id, leg_name)
        response["orderStatus"] == "CANCELLED"
      end
    end
  end
end
