# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Restricts order types to MARKET and LIMIT only.
      class OrderType
        # Every order type the Dhan order APIs accept. STOP_LOSS / STOP_LOSS_MARKET
        # must pass: they are how a stop-loss is placed.
        VALID_TYPES = DhanHQ::Constants::OrderType::ALL

        def self.run!(args:, **_unused)
          order_type = args["order_type"]
          return unless order_type
          return if VALID_TYPES.include?(order_type)

          raise DhanHQ::RiskViolation, "Invalid order type"
        end
      end
    end
  end
end
