# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests sent to the margin calculator endpoint.
    class MarginCalculatorContract < Dry::Validation::Contract
      params do
        required(:dhanClientId).filled(:string)
        required(:exchangeSegment).filled(:string, included_in?: DhanHQ::Constants::ExchangeSegment::ALL)
        required(:transactionType).filled(:string, included_in?: DhanHQ::Constants::TransactionType::ALL)
        required(:quantity).filled(:integer, gt?: 0)
        required(:productType).filled(:string, included_in?: DhanHQ::Constants::ProductType::ALL)
        required(:securityId).filled(:string)
        optional(:price).maybe(:float, gt?: 0)
        optional(:triggerPrice).maybe(:float)
      end
      rule(:price) do
        if values[:price]
          if values[:price] <= 0
            key(:price).failure("must be greater than 0")
          elsif values[:price].is_a?(Float) && (values[:price].nan? || values[:price].infinite?)
            key(:price).failure("must be a finite number")
          end
        end
      end

      rule(:triggerPrice) do
        key(:triggerPrice).failure("must be a finite number") if values[:triggerPrice].is_a?(Float) && (values[:triggerPrice].nan? || values[:triggerPrice].infinite?)
      end

      # Segment-Based Product Restrictions for margin calculations
      rule(:productType, :exchangeSegment) do
        case values[:productType]
        when DhanHQ::Constants::ProductType::CNC, DhanHQ::Constants::ProductType::MTF
          key(:productType).failure("is only allowed for Equity segments (NSE_EQ, BSE_EQ)") unless /_EQ$/.match?(values[:exchangeSegment])
        when DhanHQ::Constants::ProductType::MARGIN
          key(:productType).failure("is not allowed for Equity Cash segments; use CNC or INTRADAY") if /_EQ$/.match?(values[:exchangeSegment])
        end
      end
    end
  end
end
