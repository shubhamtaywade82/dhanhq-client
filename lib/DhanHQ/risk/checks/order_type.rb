# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Restricts order types to MARKET and LIMIT only.
      class OrderType
        VALID_TYPES = %w[MARKET LIMIT].freeze

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
