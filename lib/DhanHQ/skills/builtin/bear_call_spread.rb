# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build a bear call spread (sell OTM call, buy further OTM call).
      #
      # Steps: find instrument → spot price → option chain →
      # select strikes → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("bear_call_spread",
      #     symbol: "NIFTY",
      #     expiry: "2026-01-30",
      #     quantity: 50
      #   )
      #
      class BearCallSpread < Base
        risk "trade_adjacent_read"
        scope "orders:read"

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 50
        param :spread_width, type: :number, default: 200
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
          ltp = ctx[:instrument].ltp
          ctx[:spot_price] = ltp[:ltp] || ltp["ltp"]
          ctx
        end

        def get_option_chain(ctx)
          ctx[:chain] = ctx[:instrument].option_chain(expiry: ctx[:expiry])
          ctx
        end

        def select_strikes(ctx)
          spot = ctx[:spot_price].to_f
          chain = ctx[:chain]
          spread = ctx[:spread_width]

          ce_options = chain.select { |o| (o[:option_type] || o["optionType"]) == "CE" }
                            .sort_by { |o| (o[:strike] || o["strike"]).to_f }

          atm_strike = ce_options.min_by { |o| ((o[:strike] || o["strike"]).to_f - spot).abs }
          atm_strike_price = (atm_strike[:strike] || atm_strike["strike"]).to_f

          short_call = ce_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike_price + spread)).abs < 0.001 }
          long_call = ce_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike_price + (spread * 2))).abs < 0.001 }

          raise ArgumentError, "Could not build bear call spread — insufficient strikes in chain" unless short_call && long_call

          ctx[:legs] = [
            { action: DhanHQ::Constants::TransactionType::SELL, option_type: "CE", strike: atm_strike_price + spread,
              security_id: short_call[:security_id] || short_call["securityId"] },
            { action: DhanHQ::Constants::TransactionType::BUY, option_type: "CE", strike: atm_strike_price + (spread * 2),
              security_id: long_call[:security_id] || long_call["securityId"] }
          ]
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "BEAR_CALL_SPREAD",
            symbol: ctx[:symbol],
            expiry: ctx[:expiry],
            quantity: ctx[:quantity],
            spread_width: ctx[:spread_width],
            max_loss: ctx[:max_loss],
            legs: ctx[:legs],
            note: "Bear call spread prepared. Await human confirmation before execution."
          }
          ctx
        end
      end
    end
  end
end
