# frozen_string_literal: true

module DhanHQ
  module Models
    class ForeverOrder < BaseModel
      attributes :dhan_client_id, :order_id, :correlation_id, :order_status,
                 :transaction_type, :exchange_segment, :product_type, :order_flag,
                 :order_type, :validity, :trading_symbol, :security_id, :quantity,
                 :disclosed_quantity, :price, :trigger_price, :price1,
                 :trigger_price1, :quantity1, :leg_name, :create_time,
                 :update_time, :exchange_time, :drv_expiry_date, :drv_option_type,
                 :drv_strike_price

      class << self
        # Provides a shared instance of the ForeverOrders resource
        #
        # @return [DhanHQ::Resources::ForeverOrders]
        def resource
          @resource ||= DhanHQ::Resources::ForeverOrders.new
        end

        ##
        # Fetch all forever orders
        #
        # @return [Array<ForeverOrder>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |o| new(o, skip_validation: true) }
        end

        ##
        # Retrieve a specific forever order
        #
        # @param order_id [String]
        # @return [ForeverOrder, nil]
        def find(order_id)
          response = resource.find(order_id)
          return nil unless response.is_a?(Hash) && response.any?

          new(response, skip_validation: true)
        end

        ##
        # Create a new forever order
        #
        # @param params [Hash]
        # @return [ForeverOrder, nil]
        def create(params)
          response = resource.create(params)
          return nil unless response.is_a?(Hash) && response["orderId"]

          find(response["orderId"])
        end
      end

      ##
      # Modify an existing forever order
      #
      # @param new_params [Hash]
      # @return [ForeverOrder, nil]
      def modify(new_params)
        raise "Order ID is required to modify a forever order" unless id

        response = self.class.resource.update(id, new_params)
        return self.class.find(id) if self.class.send(:success_response?, response)

        nil
      end

      ##
      # Cancel the forever order
      #
      # @return [Boolean]
      def cancel
        raise "Order ID is required to cancel a forever order" unless id

        response = self.class.resource.cancel(id)
        response["orderStatus"] == "CANCELLED"
      end
    end
  end
end
