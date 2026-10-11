# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces daily maximum loss limit across all positions.
      class MaxLoss
        DAILY_MAX_LOSS = 50_000

        # Day P&L is realized plus unrealized: a loss booked earlier in the day
        # counts against the limit just as an open one does.
        def self.run!(positions: nil, reducing: false, **_unused)
          return if reducing

          positions ||= DhanHQ::Models::Position.all
          day_pnl = positions.sum do |p|
            p.realized_profit.to_f + p.unrealized_profit.to_f
          end
          limit = Limits.value(:daily_max_loss, DAILY_MAX_LOSS)

          return if day_pnl >= -limit

          raise DhanHQ::RiskViolation,
                "Daily loss limit of ₹#{limit} exceeded (current: ₹#{day_pnl.round(0)})"
        end
      end
    end
  end
end
