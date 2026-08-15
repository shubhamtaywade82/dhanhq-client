# frozen_string_literal: true

module Dhan
  module Orders
    # Places a Dhan order via the bang variant, so a rejection raises a
    # specific, catchable error instead of Order.place's ambiguous
    # nil/false/ErrorObject return.
    class PlaceOrder
      def initialize(params)
        @params = params
      end

      def call
        DhanHQ::Models::Order.place!(@params)
      rescue DhanHQ::OrderError => e
        Rails.logger.error("Dhan order rejected: #{e.message}")
        raise
      rescue DhanHQ::RiskViolation => e
        Rails.logger.warn("Dhan risk check blocked the order: #{e.message}")
        raise
      end
    end
  end
end
