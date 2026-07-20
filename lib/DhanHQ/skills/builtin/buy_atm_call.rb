# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to buy an ATM call option on an index.
      #
      # Steps: find instrument → get spot price → get option chain →
      # select ATM strike → prepare trade intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("buy_atm_call",
      #     symbol: "NIFTY",
      #     expiry: "2026-01-30",
      #     quantity: 50
      #   )
      #   puts result[:intent]
      #
      class BuyAtmCall < Base
        risk "trade_adjacent_read"
        scope "orders:read"
        description "Buy an at-the-money call option on an index (e.g. NIFTY)."

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 50
        param :stop_loss, type: :number, default: 100
        param :target, type: :number, default: 200

        step :find_instrument, priority: 1
        step :get_spot_price, priority: 2
        step :get_option_chain, priority: 3
        step :select_atm_strike, priority: 4
        step :prepare_intent, priority: 5

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

        def select_atm_strike(ctx)
          spot = ctx[:spot_price]
          chain = ctx[:chain]

          atm = nearest_strike(chain, spot)
          raise ArgumentError, "Could not find ATM strike" unless atm

          ctx[:selected_option] = atm
          ctx[:security_id] = leg_security_id(atm, "CE")
          ctx[:strike] = atm[:strike]
          ctx[:premium] = leg_premium(atm, "CE")
          ctx
        end

        def prepare_intent(ctx)
          ctx[:intent] = {
            trade_type: "OPTIONS_BUY",
            instrument: "#{ctx[:symbol]} #{ctx[:strike]} CE",
            security_id: ctx[:security_id],
            strike: ctx[:strike],
            expiry: ctx[:expiry],
            option_type: "CE",
            quantity: ctx[:quantity],
            premium: ctx[:premium],
            stop_loss: ctx[:stop_loss],
            target: ctx[:target],
            note: "Prepared ATM call buy. Await human confirmation."
          }
          ctx
        end
      end
    end
  end
end
