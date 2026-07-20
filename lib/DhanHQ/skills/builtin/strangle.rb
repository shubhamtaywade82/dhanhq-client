# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build a long strangle (buy OTM CE + buy OTM PE).
      #
      # Steps: find instrument → spot price → option chain → select strikes → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("strangle",
      #     symbol: "NIFTY",
      #     expiry: "2026-01-30",
      #     quantity: 50,
      #     offset_pct: 1.0
      #   )
      #
      class Strangle < Base
        risk "trade_adjacent_read"
        scope "orders:read"
        description "Build a long strangle: buy OTM call + buy OTM put around the current spot price."

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 50
        param :offset_pct, type: :number, default: 1.0
        param :stop_loss, type: :number, default: 200
        param :target, type: :number, default: 400

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
          spot = ctx[:spot_price].to_f
          chain = ctx[:chain]
          offset = ctx[:offset_pct] / 100.0

          ce_strike = spot * (1 + offset)
          pe_strike = spot * (1 - offset)

          long_ce = nearest_strike(chain, ce_strike)
          long_pe = nearest_strike(chain, pe_strike)

          raise ArgumentError, "Could not find suitable CE strike near #{ce_strike}" unless long_ce
          raise ArgumentError, "Could not find suitable PE strike near #{pe_strike}" unless long_pe

          ctx[:ce_strike] = long_ce[:strike]
          ctx[:pe_strike] = long_pe[:strike]
          ctx[:ce_security_id] = leg_security_id(long_ce, "CE")
          ctx[:pe_security_id] = leg_security_id(long_pe, "PE")
          ctx[:ce_premium] = leg_premium(long_ce, "CE")
          ctx[:pe_premium] = leg_premium(long_pe, "PE")
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "STRANGLE",
            symbol: ctx[:symbol],
            expiry: ctx[:expiry],
            quantity: ctx[:quantity],
            legs: [
              { action: DhanHQ::Constants::TransactionType::BUY, option_type: "CE", strike: ctx[:ce_strike], security_id: ctx[:ce_security_id], premium: ctx[:ce_premium] },
              { action: DhanHQ::Constants::TransactionType::BUY, option_type: "PE", strike: ctx[:pe_strike], security_id: ctx[:pe_security_id], premium: ctx[:pe_premium] }
            ],
            stop_loss: ctx[:stop_loss],
            target: ctx[:target],
            note: "Long strangle prepared. Await human confirmation."
          }
          ctx
        end
      end
    end
  end
end
