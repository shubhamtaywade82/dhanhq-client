# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Utility model for parsing Dhan postback (webhook) payloads.
    #
    # Postback is a webhook mechanism where Dhan pushes order status updates to your
    # configured URL. This model provides a convenient way to parse the incoming JSON
    # payload into a typed, attribute-accessible object.
    #
    # @note Postback URL is configured in the Dhan web console when generating an access
    #   token. It will NOT work with localhost or 127.0.0.1.
    #
    # @example Parse postback payload in a Rails controller
    #   class DhanWebhooksController < ApplicationController
    #     skip_before_action :verify_authenticity_token
    #
    #     def create
    #       postback = DhanHQ::Models::Postback.parse(request.body.read)
    #       case postback.order_status
    #       when "TRADED"
    #         handle_fill(postback)
    #       when "REJECTED"
    #         handle_rejection(postback)
    #       end
    #       head :ok
    #     end
    #   end
    #
    # @example Parse postback payload from a hash
    #   postback = DhanHQ::Models::Postback.parse(params)
    #   puts "Order #{postback.order_id} is now #{postback.order_status}"
    #   puts "Filled: #{postback.filled_qty}/#{postback.quantity}"
    #
    class Postback < BaseModel
      HTTP_PATH = nil # No API endpoint — postback is pushed to the user

      attributes :dhan_client_id, :order_id, :correlation_id, :order_status,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :validity, :trading_symbol, :security_id, :quantity,
                 :disclosed_quantity, :price, :trigger_price, :after_market_order,
                 :bo_profit_value, :bo_stop_loss_value, :leg_name,
                 :create_time, :update_time, :exchange_time,
                 :drv_expiry_date, :drv_option_type, :drv_strike_price,
                 :oms_error_code, :oms_error_description, :filled_qty, :algo_id

      class << self
        ##
        # Parse a postback webhook payload into a Postback model instance.
        #
        # Accepts either a JSON string (from request body) or a Hash (from parsed params).
        # Keys are normalized to snake_case automatically.
        #
        # @param payload [String, Hash] Raw JSON string or Hash from the webhook
        #
        # @return [Postback] Parsed Postback object with typed attributes
        #
        # @example From raw JSON string
        #   postback = DhanHQ::Models::Postback.parse('{"orderId":"123","orderStatus":"TRADED"}')
        #   puts postback.order_status # => "TRADED"
        #
        # @example From a hash
        #   postback = DhanHQ::Models::Postback.parse(order_id: "123", order_status: "TRADED")
        #   puts postback.order_id # => "123"
        #
        def parse(payload)
          data = case payload
                 when String
                   JSON.parse(payload)
                 when Hash
                   payload
                 else
                   raise ArgumentError, "Expected String or Hash, got #{payload.class}"
                 end

          new(data, skip_validation: true)
        end
      end

      ##
      # Whether the order has been fully traded.
      #
      # @return [Boolean]
      def traded?
        order_status == DhanHQ::Constants::OrderStatus::TRADED
      end

      ##
      # Whether the order was rejected.
      #
      # @return [Boolean]
      def rejected?
        order_status == DhanHQ::Constants::OrderStatus::REJECTED
      end

      ##
      # Whether the order is still pending.
      #
      # @return [Boolean]
      def pending?
        order_status == DhanHQ::Constants::OrderStatus::PENDING
      end

      ##
      # Whether the order was cancelled.
      #
      # @return [Boolean]
      def cancelled?
        order_status == DhanHQ::Constants::OrderStatus::CANCELLED
      end

      ##
      # No validation contract — postback payloads are parsed as-is.
      #
      # @return [nil]
      # @api private
      def validation_contract
        nil
      end
    end
  end
end
