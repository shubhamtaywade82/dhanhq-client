# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces quantity and notional limits for MCP tool safety.
      class Quantity
        MAX_QUANTITY = 10
        MAX_NOTIONAL = 100_000

        def self.run!(args:, **_unused)
          quantity = args["quantity"].to_i
          raise DhanHQ::RiskViolation, "Quantity must be > 0" unless quantity.positive?
          raise DhanHQ::RiskViolation, "Quantity exceeds limit" if quantity > MAX_QUANTITY

          enforce_notional_limit!(quantity, args["price"])
        end

        def self.enforce_notional_limit!(quantity, price)
          return unless price

          notional = quantity * price.to_f
          return if notional <= MAX_NOTIONAL

          raise DhanHQ::RiskViolation, "Notional exceeds limit"
        end

        private_class_method :enforce_notional_limit!
      end
    end
  end
end
