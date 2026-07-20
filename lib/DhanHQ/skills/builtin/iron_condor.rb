# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build an iron condor strategy (sell OTM CE + PE, buy further OTM CE + PE).
      #
      # Steps: find instrument → spot price → option chain → select strikes → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("iron_condor",
      #     symbol: "NIFTY",
      #     expiry: "2026-01-30",
      #     quantity: 50,
      #     wing_width: 200
      #   )
      #
      class IronCondor < Base
        risk "trade_adjacent_read"
        scope "orders:read"
        description "Build an iron condor: sell OTM call + sell OTM put, buy further OTM call + put for protection."

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 50
        param :wing_width, type: :number, default: 200
        param :max_loss, type: :number, default: 5000

        step :find_instrument, priority: 1
        step :get_spot_price, priority: 2
        step :get_option_chain, priority: 3
        step :select_strikes, priority: 4
        step :build_intent, priority: 5

        def find_instrument(ctx)
          ctx[:instrument] = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::IDX_I, ctx[:symbol])
          ctx
        end

        def get_spot_price(ctx)
          ctx[:spot_price] = ctx[:instrument].ltp
          ctx
        end

        def get_option_chain(ctx)
          ctx[:chain] = ctx[:instrument].option_chain(expiry: ctx[:expiry])
          ctx
        end

        def select_strikes(ctx)
          spot = ctx[:spot_price]
          chain = ctx[:chain]
          wing = ctx[:wing_width].to_f

          atm_strike = nearest_strike(chain, spot)[:strike].to_f

          short_ce = find_strike(chain, atm_strike + wing)
          long_ce = find_strike(chain, atm_strike + (wing * 2))
          short_pe = find_strike(chain, atm_strike - wing)
          long_pe = find_strike(chain, atm_strike - (wing * 2))

          raise ArgumentError, "Could not build iron condor — insufficient strikes in chain" unless short_ce && long_ce && short_pe && long_pe

          ctx[:legs] = [
            { action: DhanHQ::Constants::TransactionType::SELL, option_type: "CE", strike: short_ce[:strike], security_id: leg_security_id(short_ce, "CE") },
            { action: DhanHQ::Constants::TransactionType::BUY, option_type: "CE", strike: long_ce[:strike], security_id: leg_security_id(long_ce, "CE") },
            { action: DhanHQ::Constants::TransactionType::SELL, option_type: "PE", strike: short_pe[:strike], security_id: leg_security_id(short_pe, "PE") },
            { action: DhanHQ::Constants::TransactionType::BUY, option_type: "PE", strike: long_pe[:strike], security_id: leg_security_id(long_pe, "PE") }
          ]
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "IRON_CONDOR",
            symbol: ctx[:symbol],
            expiry: ctx[:expiry],
            quantity: ctx[:quantity],
            wing_width: ctx[:wing_width],
            max_loss: ctx[:max_loss],
            legs: ctx[:legs],
            note: "Iron condor prepared. Await human confirmation before execution."
          }
          ctx
        end
      end
    end
  end
end
