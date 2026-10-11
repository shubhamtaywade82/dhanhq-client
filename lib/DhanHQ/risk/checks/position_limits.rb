# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces maximum number of concurrent open positions.
      class PositionLimits
        MAX_OPEN_POSITIONS = 20

        def self.run!(positions: nil, reducing: false, **_unused)
          return if reducing

          positions ||= DhanHQ::Models::Position.all
          open_count = positions.count do |p|
            p.net_qty.to_i != 0
          end
          limit = Limits.value(:max_open_positions, MAX_OPEN_POSITIONS)

          return if open_count < limit

          raise DhanHQ::RiskViolation,
                "Maximum #{limit} open positions exceeded (#{open_count} open)"
        end
      end
    end
  end
end
