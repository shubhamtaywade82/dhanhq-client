# frozen_string_literal: true

require_relative "global_stocks_order_contract"

module DhanHQ
  module Contracts
    # Validation contract for PUT /v2/globalstocks/orders/{order-id}.
    class GlobalStocksModifyOrderContract < GlobalStocksOrderContract
      params do
        required(:order_id).filled(:string)
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:security_id).filled(:string, max_size?: 50)

        optional(:quantity).maybe(:float, gt?: 0)
        optional(:price).maybe(:float, gteq?: 0)
        optional(:leg_name).maybe(:string, included_in?: LEG_NAMES)
        optional(:dhan_client_id).maybe(:string)
      end

      rule(:order_type, :price) do
        key(:price).failure("must be greater than 0 for LIMIT orders") if PRICED_ORDER_TYPES.include?(values[:order_type]) && !values[:price]&.positive?
      end
    end
  end
end
