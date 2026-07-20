# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build a bull put spread (sell OTM put, buy further OTM put).
      #
      # Steps: find instrument → spot price → option chain →
      # select strikes → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("bull_put_spread",
      #     symbol: "NIFTY",
      #     expiry: "2026-01-30",
      #     quantity: 50
      #   )
      #
      class BullPutSpread < Base
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

          pe_options = chain.select { |o| (o[:option_type] || o["optionType"]) == "PE" }
                            .sort_by { |o| -(o[:strike] || o["strike"]).to_f }

          atm_strike = pe_options.min_by { |o| ((o[:strike] || o["strike"]).to_f - spot).abs }
          atm_strike_price = (atm_strike[:strike] || atm_strike["strike"]).to_f

          short_put = pe_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike_price - spread)).abs < 0.001 }
          long_put = pe_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike_price - (spread * 2))).abs < 0.001 }

          raise ArgumentError, "Could not build bull put spread — insufficient strikes in chain" unless short_put && long_put

          ctx[:legs] = [
            { action: DhanHQ::Constants::TransactionType::SELL, option_type: "PE", strike: atm_strike_price - spread,
              security_id: short_put[:security_id] || short_put["securityId"] },
            { action: DhanHQ::Constants::TransactionType::BUY, option_type: "PE", strike: atm_strike_price - (spread * 2),
              security_id: long_put[:security_id] || long_put["securityId"] }
          ]
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "BULL_PUT_SPREAD",
            symbol: ctx[:symbol],
            expiry: ctx[:expiry],
            quantity: ctx[:quantity],
            spread_width: ctx[:spread_width],
            max_loss: ctx[:max_loss],
            legs: ctx[:legs],
            note: "Bull put spread prepared. Await human confirmation before execution."
          }
          ctx
        end
      end
    end
  end
end
