# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Blocks trading on instruments where buy_sell_indicator is not "A".
      class TradingPermission
        def self.run!(instrument:, **_unused)
          return if instrument.buy_sell_indicator == "A"

          raise DhanHQ::RiskViolation, "Trading disabled for instrument"
        end
      end
    end
  end
end
