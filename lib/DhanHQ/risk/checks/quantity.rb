# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces quantity and notional limits for MCP tool safety.
      class Quantity
        MAX_QUANTITY = 10
        MAX_NOTIONAL = 100_000

        # Size caps apply to new exposure only; an exit of any size that does not
        # exceed the open position is allowed.
        def self.run!(args:, reducing: false, **_unused)
          quantity = args["quantity"].to_i
          raise DhanHQ::RiskViolation, "Quantity must be > 0" unless quantity.positive?
          return if reducing
          raise DhanHQ::RiskViolation, "Quantity exceeds limit" if quantity > Limits.value(:max_quantity, MAX_QUANTITY)

          enforce_notional_limit!(quantity, args["price"])
        end

        def self.enforce_notional_limit!(quantity, price)
          return unless price

          notional = quantity * price.to_f
          return if notional <= Limits.value(:max_notional, MAX_NOTIONAL)

          raise DhanHQ::RiskViolation, "Notional exceeds limit"
        end

        private_class_method :enforce_notional_limit!
      end
    end
  end
end
