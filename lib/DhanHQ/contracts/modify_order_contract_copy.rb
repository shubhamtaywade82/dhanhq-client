# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validation contract for modifying an existing order via Dhanhq's API.
    #
    # This contract validates input parameters for the Modify Order API,
    # ensuring that all required fields are provided and optional fields follow
    # the correct constraints. It also applies custom validation rules based on
    # the type of order.
    #
    # Example usage:
    #   contract = Dhanhq::Contracts::ModifyOrderContract.new
    #   result = contract.call(
    #     dhanClientId: "123456",
    #     orderId: "1001",
    #     orderType: "STOP_LOSS",
    #     legName: "ENTRY_LEG",
    #     quantity: 10,
    #     price: 150.0,
    #     triggerPrice: 140.0,
    #     validity: "DAY"
    #   )
    #   result.success? # => true or false
    #
    # @see https://dhanhq.co/docs/v2/ Dhanhq API Documentation
    class ModifyOrderContract < BaseContract
      # Parameters and validation rules for the Modify Order request.
      #
      # @!attribute [r] orderId
      #   @return [String] Required. Unique identifier for the order to be modified.
      # @!attribute [r] orderType
      #   @return [String] Required. Type of the order.
      #     Must be one of: LIMIT, MARKET, STOP_LOSS, STOP_LOSS_MARKET.
      # @!attribute [r] legName
      #   @return [String] Optional. Leg name for complex orders.
      #     Must be one of: ENTRY_LEG, TARGET_LEG, STOP_LOSS_LEG, NA.
      # @!attribute [r] quantity
      #   @return [Integer] Required. Quantity to be modified, must be greater than 0.
      # @!attribute [r] price
      #   @return [Float] Optional. Price to be modified, must be greater than 0 if provided.
      # @!attribute [r] disclosedQuantity
      #   @return [Integer] Optional. Disclosed quantity, must be >= 0 if provided.
      # @!attribute [r] triggerPrice
      #   @return [Float] Optional. Trigger price for stop-loss orders, must be greater than 0 if provided.
      # @!attribute [r] validity
      #   @return [String] Required. Validity of the order.
      #     Must be one of: DAY, IOC, GTC, GTD.
      params do
        required(:orderId).filled(:string)
        required(:orderType).filled(:string, included_in?: %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET])
        optional(:legName).maybe(:string, included_in?: %w[ENTRY_LEG TARGET_LEG STOP_LOSS_LEG NA])
        required(:quantity).filled(:integer, gt?: 0)
        optional(:price).maybe(:float, gt?: 0)
        optional(:disclosedQuantity).maybe(:integer, gteq?: 0)
        optional(:triggerPrice).maybe(:float, gt?: 0)
        required(:validity).filled(:string, included_in?: %w[DAY IOC GTC GTD])
      end

      # Custom validation to ensure a trigger price is provided for stop-loss orders.
      #
      # @example Invalid stop-loss order:
      #   orderType: "STOP_LOSS", triggerPrice: nil
      #   => Adds failure message "is required for orderType STOP_LOSS or STOP_LOSS_MARKET".
      #
      # @param triggerPrice [Float] The price at which the order will be triggered.
      # @param orderType [String] The type of the order.
      rule(:triggerPrice, :orderType) do
        if values[:orderType].start_with?("STOP_LOSS") && !values[:triggerPrice]
          key(:triggerPrice).failure("is required for orderType STOP_LOSS or STOP_LOSS_MARKET")
        end
      end

      # Custom validation to ensure a leg name is provided for CO or BO order types.
      #
      # @example Invalid CO order:
      #   orderType: "CO", legName: nil
      #   => Adds failure message "is required for orderType CO or BO".
      #
      # @param legName [String] The leg name of the order.
      # @param orderType [String] The type of the order.
      rule(:legName, :orderType) do
        if %w[CO BO].include?(values[:orderType]) && !values[:legName]
          key(:legName).failure("is required for orderType CO or BO")
        end
      end

      # Custom validation to ensure the price is valid if provided.
      #
      # @example Invalid price:
      #   price: 0
      #   => Adds failure message "must be greater than 0 if provided".
      #
      # @param price [Float] The price of the order.
      rule(:price) do
        key(:price).failure("must be greater than 0 if provided") if values[:price].nil? || values[:price] <= 0
      end
    end
  end
end
