# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates alert order payloads for create/update (exchange_segment, security_id,
    # condition, trigger_price, transaction_type, quantity; optional price, order_type).
    class AlertOrderContract < BaseContract
      params do
        required(:exchange_segment).filled(:string)
        required(:security_id).filled(:string)
        required(:condition).filled(:string)
        required(:trigger_price).filled(:float)
        required(:transaction_type).filled(:string, included_in?: %w[BUY SELL])
        required(:quantity).filled(:integer, gt?: 0)
        optional(:price).maybe(:float)
        optional(:order_type).maybe(:string)
      end
    end
  end
end
