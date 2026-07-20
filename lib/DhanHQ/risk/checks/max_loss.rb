# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces daily maximum loss limit across all positions.
      class MaxLoss
        DAILY_MAX_LOSS = 50_000

        def self.run!(**_unused)
          positions = DhanHQ::Models::Position.all
          total_unrealized_loss = positions.sum do |p|
            p.unrealized_profit.to_f
          end

          return if total_unrealized_loss >= -DAILY_MAX_LOSS

          raise DhanHQ::RiskViolation,
                "Daily loss limit of ₹#{DAILY_MAX_LOSS} exceeded (current: ₹#{total_unrealized_loss.round(0)})"
        end
      end
    end
  end
end
