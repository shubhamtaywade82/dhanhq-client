# frozen_string_literal: true

require_relative "../contracts/place_order_contract"
require_relative "../contracts/modify_order_contract"

module DhanHQ
  # ActiveRecord-style models built on top of the REST resources.
  module Models
    # Representation of an order as returned by the REST APIs.
    class Order < BaseModel
      # Attributes eligible for modification requests.
      MODIFIABLE_FIELDS = %i[
        dhan_client_id
        order_id
        order_type
        quantity
        price
        trigger_price
        disclosed_quantity
        validity
        leg_name
      ].freeze

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
          return nil unless response.is_a?(Hash) || (response.is_a?(Array) && response.any?)

          order_data = response.is_a?(Array) ? response.first : response
          new(order_data, skip_validation: true)
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
          normalized_params = snake_case(params)
          validate_params!(normalized_params, DhanHQ::Contracts::PlaceOrderContract)

          response = resource.create(camelize_keys(normalized_params))
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

        base_payload = attributes.merge(new_params)
        normalized_payload = snake_case(base_payload).merge(order_id: id)
        filtered_payload = normalized_payload.each_with_object({}) do |(key, value), memo|
          symbolized_key = key.respond_to?(:to_sym) ? key.to_sym : key
          memo[symbolized_key] = value if MODIFIABLE_FIELDS.include?(symbolized_key)
        end
        filtered_payload[:order_id] ||= id
        filtered_payload[:dhan_client_id] ||= attributes[:dhan_client_id]

        cleaned_payload = filtered_payload.compact
        formatted_payload = camelize_keys(cleaned_payload)
        validate_params!(formatted_payload, DhanHQ::Contracts::ModifyOrderContract)

        response = self.class.resource.update(id, formatted_payload)
        response = response.with_indifferent_access if response.respond_to?(:with_indifferent_access)

        return DhanHQ::ErrorObject.new(response) unless success_response?(response)

        @attributes.merge!(normalize_keys(response))
        assign_attributes
        self
      end

      # Cancel the order
      #
      # @return [Boolean]
      def cancel
        raise "Order ID is required to cancel an order" unless id

        response = self.class.resource.cancel(id)
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
        raise "Order ID is required to slice an order" unless id

        base_payload = params.merge(order_id: id)
        formatted_payload = camelize_keys(base_payload)

        validate_params!(formatted_payload, DhanHQ::Contracts::SliceOrderContract)

        self.class.resource.slicing(formatted_payload)
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
