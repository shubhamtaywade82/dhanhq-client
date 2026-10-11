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
        #
        # A MARKET entry carries no price, so its notional is estimated from the
        # trigger price or the instrument's LTP; an entry that cannot be priced is
        # refused rather than counted as zero exposure.
        def self.run!(args:, positions: nil, reducing: false, instrument: nil, **_unused)
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
          order_notional = order_notional(args, instrument)
          limit = Limits.value(:max_concentration_pct, MAX_CONCENTRATION_PCT)

          concentration_pct = ((current_exposure + order_notional) / available) * 100.0
          return if concentration_pct <= limit

          raise DhanHQ::RiskViolation,
                "Concentration #{concentration_pct.round(1)}% exceeds #{limit}% limit for #{symbol.empty? ? security_id : symbol}"
        end

        def self.order_notional(args, instrument)
          quantity = args["quantity"].to_i
          return 0.0 unless quantity.positive?

          quantity * order_price!(args, instrument)
        end

        def self.order_price!(args, instrument)
          price = [args["price"], args["trigger_price"]].map(&:to_f).find(&:positive?)
          price ||= live_price(instrument)
          return price if price&.positive?

          raise DhanHQ::RiskViolation,
                "Cannot price #{args["security_id"] || args["trading_symbol"]} for the concentration check " \
                "(no price, trigger price or LTP)"
        end

        # A failed LTP fetch must refuse the entry, not escape as a generic error:
        # OrderAudit treats unexpected errors as "skip every check".
        def self.live_price(instrument)
          return nil unless instrument.respond_to?(:ltp)

          instrument.ltp.to_f
        rescue StandardError => e
          DhanHQ.logger&.warn("[DhanHQ::Risk::Concentration] LTP fetch failed: #{e.class} #{e.message}")
          nil
        end

        def self.same_instrument?(position, args, security_id, symbol)
          return position.trading_symbol.to_s == symbol unless symbol.empty?

          position.security_id.to_s == security_id &&
            (args["exchange_segment"].nil? || position.exchange_segment.to_s == args["exchange_segment"].to_s)
        end

        private_class_method :order_notional, :order_price!, :live_price, :same_instrument?
      end
    end
  end
end
