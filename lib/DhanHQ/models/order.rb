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
        ##
        # Provides a **shared instance** of the `Orders` resource
        #
        # @return [DhanHQ::Resources::Orders]
        def resource
          @resource ||= DhanHQ::Resources::Orders.new
        end

        ##
        # Fetch all orders for the day.
        #
        # @return [Array<Order>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |order| new(order, skip_validation: true) }
        end

        ##
        # Fetch a specific order by ID.
        #
        # @param order_id [String]
        # @return [Order, nil]
        def find(order_id)
          response = resource.find(order_id)
          return nil unless response.is_a?(Hash) && response.any?

          new(response, skip_validation: true)
        end

        ##
        # Fetch a specific order by correlation ID.
        #
        # @param correlation_id [String]
        # @return [Order, nil]
        def find_by_correlation(correlation_id)
          response = resource.by_correlation(correlation_id)
          return nil unless response[:status] == "success"

          new(response, skip_validation: true)
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

        ##
        # AR-like create: new => valid? => save => resource.create
        # But we can also define a class method if we want direct:
        #   Order.create(order_params)
        #
        # For the typical usage "Order.new(...).save", we rely on #save below.
        def create(params)
          order = new(params) # build it
          return order unless order.valid? # run place order contract?

          order.save # calls resource create or update
          order
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

        # response = self.class.api.put("#{self.class.resource_path}/#{id}", params: attributes)
        update(attributes)
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

      ##
      # This is how we figure out if it's an existing record or not:
      def new_record?
        order_id.nil? || order_id.to_s.empty?
      end

      ##
      # The ID used for resource calls
      def id
        order_id
      end

      ##
      # Save: If new_record?, do resource.create
      # else resource.update
      def save
        return false unless valid?

        if new_record?
          # PLACE ORDER
          response = self.class.resource.create(to_request_params)
          if success_response?(response) && response["orderId"]
            @attributes.merge!(normalize_keys(response))
            assign_attributes
            true
          else
            # maybe store errors?
            false
          end
        else
          # MODIFY ORDER
          response = self.class.resource.update(id, to_request_params)
          if success_response?(response) && response["orderStatus"]
            @attributes.merge!(normalize_keys(response))
            assign_attributes
            true
          else
            false
          end
        end
      end

      ##
      # Cancel => calls resource.delete
      def destroy
        return false if new_record?

        response = self.class.resource.delete(id)
        if success_response?(response) && response["orderStatus"] == "CANCELLED"
          @attributes[:order_status] = "CANCELLED"
          true
        else
          false
        end
      end
      alias delete destroy

      ##
      # Slicing (optional)
      # If you want an AR approach:
      def slice_order(params)
        self.class.resource.slicing(params.merge(order_id: id))
      end

      ##
      # Because we have two separate contracts: place vs. modify
      # We can do something like:
      def validation_contract
        new_record? ? DhanHQ::Contracts::PlaceOrderContract.new : DhanHQ::Contracts::ModifyOrderContract.new
      end
    end
  end
end
