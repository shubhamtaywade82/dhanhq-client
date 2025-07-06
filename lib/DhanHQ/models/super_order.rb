# frozen_string_literal: true

module DhanHQ
  module Models
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
        def resource
          @resource ||= DhanHQ::Resources::SuperOrders.new
        end

        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |o| new(o, skip_validation: true) }
        end

        def create(params)
          response = resource.create(params)
          return nil unless response.is_a?(Hash) && response["orderId"]

          new(order_id: response["orderId"], order_status: response["orderStatus"], skip_validation: true)
        end
      end

      def modify(new_params)
        raise "Order ID is required to modify a super order" unless id

        response = self.class.resource.update(id, new_params)
        response["orderId"] == id
      end

      def cancel(leg_name = "ENTRY_LEG")
        raise "Order ID is required to cancel a super order" unless id

        response = self.class.resource.cancel(id, leg_name)
        response["orderStatus"] == "CANCELLED"
      end
    end
  end
end
