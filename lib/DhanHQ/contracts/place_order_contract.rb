# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validation contract for placing an order via Dhanhq's API.
    #
    # This contract validates the parameters required to place an order,
    # ensuring the correctness of inputs based on API requirements. It includes:
    # - Mandatory fields for order placement.
    # - Conditional validation for optional fields based on provided values.
    # - Validation of enumerated values using constants for consistency.
    #
    # Example usage:
    #   contract = Dhanhq::Contracts::PlaceOrderContract.new
    #   result = contract.call(
    #     dhanClientId: "123456",
    #     transaction_type: "BUY",
    #     exchange_segment: "NSE_EQ",
    #     product_type: "CNC",
    #     order_type: "LIMIT",
    #     validity: "DAY",
    #     security_id: "1001",
    #     quantity: 10,
    #     price: 150.0
    #   )
    #   result.success? # => true or false
    #
    # @see https://dhanhq.co/docs/v2/ Dhanhq API Documentation
    class PlaceOrderContract < BaseContract
      # Parameters and validation rules for the place order request.
      #
      # @!attribute [r] correlation_id
      #   @return [String] Optional. Identifier for tracking, max length 25 characters.
      # @!attribute [r] transaction_type
      #   @return [String] Required. BUY or SELL.
      # @!attribute [r] exchange_segment
      #   @return [String] Required. Exchange segment for the order.
      #     Must be one of: `EXCHANGE_SEGMENTS`.
      # @!attribute [r] product_type
      #   @return [String] Required. Product type for the order.
      #     Must be one of: `PRODUCT_TYPES`.
      # @!attribute [r] order_type
      #   @return [String] Required. Type of order.
      #     Must be one of: `ORDER_TYPES`.
      # @!attribute [r] validity
      #   @return [String] Required. Validity of the order.
      #     Must be one of: DAY, IOC.
      # @!attribute [r] trading_symbol
      #   @return [String] Optional. Trading symbol of the instrument.
      # @!attribute [r] security_id
      #   @return [String] Required. Security identifier for the order.
      # @!attribute [r] quantity
      #   @return [Integer] Required. Quantity of the order, must be greater than 0.
      # @!attribute [r] disclosed_quantity
      #   @return [Integer] Optional. Disclosed quantity, must be >= 0 if provided.
      # @!attribute [r] price
      #   @return [Float] Optional. Price for the order, must be > 0 if provided.
      # @!attribute [r] trigger_price
      #   @return [Float] Optional. Trigger price for stop-loss orders, must be > 0 if provided.
      # @!attribute [r] after_market_order
      #   @return [Boolean] Optional. Indicates if this is an after-market order.
      # @!attribute [r] amo_time
      #   @return [String] Optional. Time for after-market orders. Must be one of: OPEN, OPEN_30, OPEN_60.
      # @!attribute [r] bo_profit_value
      #   @return [Float] Optional. Profit value for Bracket Orders, must be > 0 if provided.
      # @!attribute [r] bo_stop_loss_value
      #   @return [Float] Optional. Stop-loss value for Bracket Orders, must be > 0 if provided.
      # @!attribute [r] drv_expiry_date
      #   @return [String] Optional. Expiry date for derivative contracts.
      # @!attribute [r] drv_option_type
      #   @return [String] Optional. Option type for derivatives, must be one of: CALL, PUT, NA.
      # @!attribute [r] drv_strike_price
      #   @return [Float] Optional. Strike price for options, must be > 0 if provided.
      params do
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
        required(:product_type).filled(:string, included_in?: PRODUCT_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        required(:security_id).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
        optional(:trading_symbol).maybe(:string)
        optional(:correlation_id).maybe(:string, max_size?: 25)
        optional(:price).maybe(:float, gt?: 0)
        optional(:trigger_price).maybe(:float, gt?: 0)
        optional(:after_market_order).maybe(:bool)
        optional(:amo_time).maybe(:string, included_in?: %w[OPEN OPEN_30 OPEN_60])
        optional(:bo_profit_value).maybe(:float, gt?: 0)
        optional(:bo_stop_loss_value).maybe(:float, gt?: 0)
        optional(:drv_expiry_date).maybe(:string)
        optional(:drv_option_type).maybe(:string, included_in?: %w[CALL PUT NA])
        optional(:drv_strike_price).maybe(:float, gt?: 0)
      end

      # Validate that float values are finite (not NaN or Infinity) and within reasonable bounds
      rule(:price) do
        if values[:price].is_a?(Float)
          if values[:price].nan? || values[:price].infinite?
            key(:price).failure("must be a finite number")
          elsif values[:price] > 1_000_000_000
            key(:price).failure("must be less than 1,000,000,000")
          end
        end
      end

      rule(:trigger_price) do
        if values[:trigger_price].is_a?(Float)
          if values[:trigger_price].nan? || values[:trigger_price].infinite?
            key(:trigger_price).failure("must be a finite number")
          elsif values[:trigger_price] > 1_000_000_000
            key(:trigger_price).failure("must be less than 1,000,000,000")
          end
        end
      end

      rule(:bo_profit_value) do
        if values[:bo_profit_value].is_a?(Float)
          if values[:bo_profit_value].nan? || values[:bo_profit_value].infinite?
            key(:bo_profit_value).failure("must be a finite number")
          elsif values[:bo_profit_value] > 1_000_000_000
            key(:bo_profit_value).failure("must be less than 1,000,000,000")
          end
        end
      end

      rule(:bo_stop_loss_value) do
        if values[:bo_stop_loss_value].is_a?(Float)
          if values[:bo_stop_loss_value].nan? || values[:bo_stop_loss_value].infinite?
            key(:bo_stop_loss_value).failure("must be a finite number")
          elsif values[:bo_stop_loss_value] > 1_000_000_000
            key(:bo_stop_loss_value).failure("must be less than 1,000,000,000")
          end
        end
      end

      rule(:drv_strike_price) do
        if values[:drv_strike_price].is_a?(Float)
          if values[:drv_strike_price].nan? || values[:drv_strike_price].infinite?
            key(:drv_strike_price).failure("must be a finite number")
          elsif values[:drv_strike_price] > 1_000_000_000
            key(:drv_strike_price).failure("must be less than 1,000,000,000")
          end
        end
      end

      # Custom validation for trigger price when the order type is STOP_LOSS or STOP_LOSS_MARKET.
      rule(:trigger_price, :order_type) do
        if values[:order_type] =~ /^STOP_LOSS/ && !values[:trigger_price]
          key(:trigger_price).failure("is required for order_type STOP_LOSS or STOP_LOSS_MARKET")
        end
      end

      # Custom validation for AMO time when the order is marked as after-market.
      rule(:after_market_order, :amo_time) do
        if values[:after_market_order] == true && !values[:amo_time]
          key(:amo_time).failure("is required when after_market_order is true")
        end
      end

      # Custom validation for Bracket Order (BO) fields.
      rule(:bo_profit_value, :bo_stop_loss_value, :product_type) do
        if values[:product_type] == DhanHQ::Constants::ProductType::BO && (!values[:bo_profit_value] || !values[:bo_stop_loss_value])
          key(:bo_profit_value).failure("is required for Bracket Orders")
          key(:bo_stop_loss_value).failure("is required for Bracket Orders")
        end
      end
    end
  end
end
