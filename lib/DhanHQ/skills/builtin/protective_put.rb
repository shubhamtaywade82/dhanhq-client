# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build a protective put strategy (buy stock, buy OTM put).
      #
      # Steps: find instrument → spot price → option chain →
      # select OTM put → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("protective_put",
      #     symbol: "RELIANCE",
      #     expiry: "2026-01-30",
      #     quantity: 100
      #   )
      #
      class ProtectivePut < Base
        risk "trade_adjacent_read"
        scope "orders:read"
        description "Build a protective put: buy the underlying equity, buy an OTM put as downside insurance."

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 100
        param :strike_offset, type: :number, default: 2.0
        param :max_premium_pct, type: :number, default: 3.0

        step :find_instrument, priority: 1
        step :get_spot_price, priority: 2
        step :get_option_chain, priority: 3
        step :select_otm_put, priority: 4
        step :build_intent, priority: 5

        def find_instrument(ctx)
          ctx[:instrument] = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, ctx[:symbol])
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

        def select_otm_put(ctx)
          spot = ctx[:spot_price].to_f
          chain = ctx[:chain]
          offset_pct = ctx[:strike_offset] / 100.0
          max_prem = ctx[:max_premium_pct] / 100.0

          target_strike = spot * (1 - offset_pct)
          otm_put = nearest_strike(chain, target_strike)

          raise ArgumentError, "Could not find suitable OTM put strike near #{target_strike}" unless otm_put

          premium = leg_premium(otm_put, "PE").to_f
          premium_pct = premium / spot

          raise ArgumentError, "Put premium #{premium_pct * 100}% exceeds max #{ctx[:max_premium_pct]}%" if premium_pct > max_prem

          ctx[:put_strike] = otm_put[:strike]
          ctx[:put_security_id] = leg_security_id(otm_put, "PE")
          ctx[:put_premium] = premium
          ctx[:equity_security_id] = ctx[:instrument].security_id
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "PROTECTIVE_PUT",
            symbol: ctx[:symbol],
            quantity: ctx[:quantity],
            legs: [
              { action: DhanHQ::Constants::TransactionType::BUY, instrument_type: DhanHQ::Constants::InstrumentType::EQUITY, security_id: ctx[:equity_security_id],
                quantity: ctx[:quantity] },
              { action: DhanHQ::Constants::TransactionType::BUY, option_type: "PE", strike: ctx[:put_strike], security_id: ctx[:put_security_id], quantity: ctx[:quantity], premium: ctx[:put_premium] }
            ],
            note: "Protective put prepared: Buy #{ctx[:quantity]} #{ctx[:symbol]}, Buy #{ctx[:quantity]} #{ctx[:put_strike]} PE. Await human confirmation."
          }
          ctx
        end
      end
    end
  end
end
