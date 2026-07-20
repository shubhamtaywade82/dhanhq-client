# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces maximum portfolio concentration in any single symbol.
      class Concentration
        MAX_CONCENTRATION_PCT = 25.0

        def self.run!(args:, **_unused)
          symbol = args["trading_symbol"] || args["security_id"]
          return unless symbol

          funds = DhanHQ::Models::Funds.fetch
          available = funds.available_balance.to_f
          return if available <= 0

          positions = DhanHQ::Models::Position.all
          symbol_positions = positions.select do |p|
            sym = p.trading_symbol || p.security_id
            sym.to_s == symbol.to_s
          end

          current_exposure = symbol_positions.sum do |p|
            p.net_qty.to_i.abs * p.cost_price.to_f
          end

          concentration_pct = (current_exposure / available) * 100.0
          return if concentration_pct <= MAX_CONCENTRATION_PCT

          raise DhanHQ::RiskViolation,
                "Concentration #{concentration_pct.round(1)}% exceeds #{MAX_CONCENTRATION_PCT}% limit for #{symbol}"
        end
      end
    end
  end
end
