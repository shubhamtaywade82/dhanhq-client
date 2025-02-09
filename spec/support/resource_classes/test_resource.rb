# frozen_string_literal: true

module DhanHQ
  class TestResource < BaseModel
    HTTP_PATH = "/test_resources"

    attributes :dhan_client_id, :correlation_id, :transaction_type, :exchange_segment,
               :product_type, :order_type, :validity, :security_id, :quantity,
               :disclosed_quantity, :price, :trigger_price, :after_market_order,
               :amo_time, :bo_profit_value, :bo_stop_loss_value

    class << self
      def validation_contract
        @validation_contract ||= Class.new(Dry::Validation::Contract) do
          params do
            required(:dhanClientId).filled(:string)
            required(:correlationId).filled(:string)
            required(:transactionType).filled(:string, included_in?: DhanHQ::Constants::TRANSACTION_TYPES)
            required(:exchangeSegment).filled(:string, included_in?: DhanHQ::Constants::EXCHANGE_SEGMENTS)
            required(:productType).filled(:string, included_in?: DhanHQ::Constants::PRODUCT_TYPES)
            required(:orderType).filled(:string, included_in?: DhanHQ::Constants::ORDER_TYPES)
            required(:validity).filled(:string, included_in?: DhanHQ::Constants::VALIDITY_TYPES)
            required(:securityId).filled(:string)
            required(:quantity).filled(:integer, gt?: 0)
            optional(:disclosedQuantity).maybe(:integer)
            optional(:price).maybe(:float)
            optional(:triggerPrice).maybe(:float)
            optional(:afterMarketOrder).maybe(:bool)
            optional(:amoTime).maybe(:string, included_in?: DhanHQ::Constants::AMO_TIMINGS)
            optional(:boProfitValue).maybe(:float)
            optional(:boStopLossValue).maybe(:float)
          end
        end
      end
    end
  end
end
