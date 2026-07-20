# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build a covered call strategy (buy 100 shares, sell 1 OTM call).
      #
      # Steps: find equity instrument → spot price → option chain →
      # select OTM call strike → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("covered_call",
      #     symbol: "RELIANCE",
      #     expiry: "2026-01-30",
      #     quantity: 100
      #   )
      #
      class CoveredCall < Base
        risk "trade_adjacent_read"
        scope "orders:read"
        description "Build a covered call: buy the underlying equity, sell an OTM call against it."

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 100
        param :strike_offset, type: :number, default: 2.0
        param :stop_loss, type: :number, default: nil
        param :target, type: :number, default: nil

        step :find_instrument, priority: 1
        step :get_spot_price, priority: 2
        step :get_option_chain, priority: 3
        step :select_otm_call, priority: 4
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

        def select_otm_call(ctx)
          spot = ctx[:spot_price].to_f
          chain = ctx[:chain]
          offset_pct = ctx[:strike_offset] / 100.0

          target_strike = spot * (1 + offset_pct)
          otm_call = nearest_strike(chain, target_strike)

          raise ArgumentError, "Could not find suitable OTM call strike near #{target_strike}" unless otm_call

          ctx[:call_strike] = otm_call[:strike]
          ctx[:call_security_id] = leg_security_id(otm_call, "CE")
          ctx[:call_premium] = leg_premium(otm_call, "CE")
          ctx[:equity_security_id] = ctx[:instrument].security_id
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "COVERED_CALL",
            symbol: ctx[:symbol],
            quantity: ctx[:quantity],
            legs: [
              { action: DhanHQ::Constants::TransactionType::BUY, instrument_type: DhanHQ::Constants::InstrumentType::EQUITY, security_id: ctx[:equity_security_id],
                quantity: ctx[:quantity] },
              { action: DhanHQ::Constants::TransactionType::SELL, option_type: "CE", strike: ctx[:call_strike], security_id: ctx[:call_security_id], quantity: ctx[:quantity], premium: ctx[:call_premium] }
            ],
            note: "Covered call prepared: Buy #{ctx[:quantity]} #{ctx[:symbol]}, Sell #{ctx[:quantity]} #{ctx[:call_strike]} CE. Await human confirmation."
          }
          ctx
        end
      end
    end
  end
end
