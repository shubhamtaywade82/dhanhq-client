# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request for POST /v2/forever/orders (create Forever / GTT order).
    # orderFlag: SINGLE | OCO. productType: CNC | MTF. For OCO, price1, triggerPrice1, quantity1 required.
    class ForeverOrderCreateContract < BaseContract
      params do
        required(:dhan_client_id).filled(:string)
        required(:order_flag).filled(:string, included_in?: OrderFlag::ALL)
        required(:transaction_type).filled(:string, included_in?: TRANSACTION_TYPES)
        required(:exchange_segment).filled(:string, included_in?: FOREVER_ORDER_SEGMENTS)
        required(:product_type).filled(:string, included_in?: FOREVER_ORDER_PRODUCT_TYPES)
        required(:order_type).filled(:string, included_in?: %w[LIMIT MARKET])
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        required(:security_id).filled(:string)
        required(:quantity).filled(:integer, gt?: 0)
        required(:price).filled(:float, gt?: 0)
        required(:trigger_price).filled(:float)
        optional(:correlation_id).maybe(:string, max_size?: 30, format?: /\A[a-zA-Z0-9 _-]*\z/)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
        optional(:price1).maybe(:float, gt?: 0)
        optional(:trigger_price1).maybe(:float)
        optional(:quantity1).maybe(:integer, gt?: 0)
      end

      rule(:order_flag) do
        next unless value == DhanHQ::Constants::OrderFlag::OCO

        missing = []
        missing << "price1" if values[:price1].nil? || values[:price1].to_f <= 0
        missing << "trigger_price1" if values[:trigger_price1].nil?
        missing << "quantity1" if values[:quantity1].nil? || values[:quantity1].to_i < 1
        key.failure("required for OCO: #{missing.join(", ")}") if missing.any?
      end
    end

    # Validates request for PUT /v2/forever/orders/{order-id} (modify Forever order).
    # orderType: LIMIT | MARKET | STOP_LOSS | STOP_LOSS_MARKET. legName: TARGET_LEG | STOP_LOSS_LEG.
    class ForeverOrderModifyContract < BaseContract
      params do
        required(:dhan_client_id).filled(:string)
        required(:order_id).filled(:string)
        required(:order_flag).filled(:string, included_in?: OrderFlag::ALL)
        required(:order_type).filled(:string, included_in?: ORDER_TYPES)
        required(:leg_name).filled(:string, included_in?: %w[TARGET_LEG STOP_LOSS_LEG])
        required(:quantity).filled(:integer, gt?: 0)
        required(:price).filled(:float, gt?: 0)
        required(:trigger_price).filled(:float)
        required(:validity).filled(:string, included_in?: VALIDITY_TYPES)
        optional(:disclosed_quantity).maybe(:integer, gteq?: 0)
      end
    end
  end
end
