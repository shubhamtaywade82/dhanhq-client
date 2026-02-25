# frozen_string_literal: true

require_relative "base_contract"

module DhanHQ
  module Contracts
    # Validation contract for slicing an order into multiple parts for Dhanhq's API.
    #
    # This contract ensures all required parameters are provided and optional parameters
    # meet the required constraints when they are specified. It validates:
    # - Required fields for slicing orders.
    # - Conditional logic for fields based on the provided values.
    # - Constraints such as inclusion, numerical ranges, and string formats.
    #
    # Example usage:
    #   contract = Dhanhq::Contracts::SliceOrderContract.new
    #   result = contract.call(
    #     dhanClientId: "123456",
    #     transactionType: "BUY",
    #     exchangeSegment: "NSE_EQ",
    #     productType: "CNC",
    #     orderType: "LIMIT",
    #     validity: "DAY",
    #     securityId: "1001",
    #     quantity: 10
    #   )
    #   result.success? # => true or false
    #
    # @see https://dhanhq.co/docs/v2/ Dhanhq API Documentation
    class SliceOrderContract < BaseContract
      # Parameters and validation rules for the slicing order request.
      #
      # @!attribute [r] correlationId
      #   @return [String] Optional. Identifier for tracking, max length 25 characters.
      # @!attribute [r] transactionType
      #   @return [String] Required. BUY or SELL.
      # @!attribute [r] exchangeSegment
      #   @return [String] Required. The segment in which the order is placed.
      #     Must be one of: NSE_EQ, NSE_FNO, NSE_CURRENCY, BSE_EQ, BSE_FNO, BSE_CURRENCY, MCX_COMM.
      # @!attribute [r] productType
      #   @return [String] Required. Product type for the order.
      #     Must be one of: CNC, INTRADAY, MARGIN, MTF, CO, BO.
      # @!attribute [r] orderType
      #   @return [String] Required. Type of order.
      #     Must be one of: LIMIT, MARKET, STOP_LOSS, STOP_LOSS_MARKET.
      # @!attribute [r] validity
      #   @return [String] Required. Validity of the order.
      #     Must be one of: DAY, IOC, GTC, GTD.
      # @!attribute [r] securityId
      #   @return [String] Required. Security identifier for the order.
      # @!attribute [r] quantity
      #   @return [Integer] Required. Quantity of the order, must be greater than 0.
      # @!attribute [r] disclosedQuantity
      #   @return [Integer] Optional. Disclosed quantity, must be >= 0 if provided.
      # @!attribute [r] price
      #   @return [Float] Optional. Price for the order, must be > 0 if provided.
      # @!attribute [r] triggerPrice
      #   @return [Float] Optional. Trigger price for stop-loss orders, must be > 0 if provided.
      # @!attribute [r] afterMarketOrder
      #   @return [Boolean] Optional. Indicates if this is an after-market order.
      # @!attribute [r] amoTime
      #   @return [String] Optional. Time for after-market orders. Must be one of: OPEN, OPEN_30, OPEN_60.
      # @!attribute [r] boProfitValue
      #   @return [Float] Optional. Profit value for Bracket Orders, must be > 0 if provided.
      # @!attribute [r] boStopLossValue
      #   @return [Float] Optional. Stop-loss value for Bracket Orders, must be > 0 if provided.
      # @!attribute [r] drvExpiryDate
      #   @return [String] Optional. Expiry date for derivative contracts.
      # @!attribute [r] drvOptionType
      #   @return [String] Optional. Option type for derivatives, must be one of: CALL, PUT, NA.
      # @!attribute [r] drvStrikePrice
      #   @return [Float] Optional. Strike price for options, must be > 0 if provided.
      params do
        optional(:correlationId).maybe(:string, max_size?: 25)
        required(:transactionType).filled(:string, included_in?: %w[BUY SELL])
        required(:exchangeSegment).filled(:string,
                                          included_in?: %w[NSE_EQ NSE_FNO NSE_CURRENCY BSE_EQ BSE_FNO BSE_CURRENCY
                                                           MCX_COMM])
        required(:productType).filled(:string, included_in?: %w[CNC INTRADAY MARGIN MTF CO BO])
        required(:orderType).filled(:string, included_in?: %w[LIMIT MARKET STOP_LOSS STOP_LOSS_MARKET])
        required(:validity).filled(:string, included_in?: %w[DAY IOC GTC GTD])
        required(:securityId).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)
        optional(:disclosedQuantity).maybe(:integer, gteq?: 0)
        optional(:price).maybe(:float, gt?: 0)
        optional(:triggerPrice).maybe(:float, gt?: 0)
        optional(:afterMarketOrder).maybe(:bool)
        optional(:amoTime).maybe(:string, included_in?: %w[OPEN OPEN_30 OPEN_60])
        optional(:boProfitValue).maybe(:float, gt?: 0)
        optional(:boStopLossValue).maybe(:float, gt?: 0)
        optional(:drvExpiryDate).maybe(:string)
        optional(:drvOptionType).maybe(:string, included_in?: %w[CALL PUT NA])
        optional(:drvStrikePrice).maybe(:float, gt?: 0)
      end

      # Custom validation for trigger price when the order type is STOP_LOSS or STOP_LOSS_MARKET.
      rule(:triggerPrice, :orderType) do
        if values[:orderType].start_with?(DhanHQ::Constants::OrderType::STOP_LOSS) && !values[:triggerPrice]
          key(:triggerPrice).failure("is required for orderType STOP_LOSS or STOP_LOSS_MARKET")
        end
      end

      # Custom validation for AMO time when the order is marked as after-market.
      rule(:afterMarketOrder, :amoTime) do
        if values[:afterMarketOrder] == true && !values[:amoTime]
          key(:amoTime).failure("is required when afterMarketOrder is true")
        end
      end
    end
  end
end
