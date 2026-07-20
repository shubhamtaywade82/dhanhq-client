# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces maximum number of concurrent open positions.
      class PositionLimits
        MAX_OPEN_POSITIONS = 20

        def self.run!(**_unused)
          positions = DhanHQ::Models::Position.all
          open_count = positions.count do |p|
            p.net_qty.to_i != 0
          end

          return if open_count < MAX_OPEN_POSITIONS

          raise DhanHQ::RiskViolation,
                "Maximum #{MAX_OPEN_POSITIONS} open positions exceeded (#{open_count} open)"
        end
      end
    end
  end
end
