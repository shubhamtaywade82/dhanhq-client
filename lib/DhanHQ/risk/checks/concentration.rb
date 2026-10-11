# frozen_string_literal: true

module DhanHQ
  module Risk
    module Checks
      # Enforces maximum portfolio concentration in any single symbol.
      class Concentration
        MAX_CONCENTRATION_PCT = 25.0

        # Exposure in one instrument — open positions plus this order's notional —
        # as a share of available funds. Positions match on security id (and segment
        # when given) or, when the order names one, on trading symbol. Order params
        # usually carry only a security id, and comparing that against a position's
        # trading symbol never matched, which left this check inert for orders.
        def self.run!(args:, positions: nil, reducing: false, **_unused)
          security_id = args["security_id"].to_s
          symbol = args["trading_symbol"].to_s
          return if reducing || (security_id.empty? && symbol.empty?)

          funds = DhanHQ::Models::Funds.fetch
          available = funds.available_balance.to_f
          return if available <= 0

          positions ||= DhanHQ::Models::Position.all
          symbol_positions = positions.select { |p| same_instrument?(p, args, security_id, symbol) }

          current_exposure = symbol_positions.sum do |p|
            p.net_qty.to_i.abs * p.cost_price.to_f
          end
          order_notional = args["quantity"].to_i * args["price"].to_f
          limit = Limits.value(:max_concentration_pct, MAX_CONCENTRATION_PCT)

          concentration_pct = ((current_exposure + order_notional) / available) * 100.0
          return if concentration_pct <= limit

          raise DhanHQ::RiskViolation,
                "Concentration #{concentration_pct.round(1)}% exceeds #{limit}% limit for #{symbol.empty? ? security_id : symbol}"
        end

        def self.same_instrument?(position, args, security_id, symbol)
          return position.trading_symbol.to_s == symbol unless symbol.empty?

          position.security_id.to_s == security_id &&
            (args["exchange_segment"].nil? || position.exchange_segment.to_s == args["exchange_segment"].to_s)
        end

        private_class_method :same_instrument?
      end
    end
  end
end
