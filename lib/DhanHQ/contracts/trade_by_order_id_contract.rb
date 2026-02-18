# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validation contract for trade-by-order-id requests.
    class TradeByOrderIdContract < BaseContract
      params do
        required(:order_id).filled(:string, min_size?: 1)
      end
    end
  end
end
