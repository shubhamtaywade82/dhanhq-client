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
          wing = ctx[:wing_width]

          ce_options = chain.select { |o| (o[:option_type] || o["optionType"]) == "CE" }
                            .sort_by { |o| (o[:strike] || o["strike"]).to_f }
          pe_options = chain.select { |o| (o[:option_type] || o["optionType"]) == "PE" }
                            .sort_by { |o| (o[:strike] || o["strike"]).to_f }

          atm = ce_options.min_by { |o| (o[:strike] || o["strike"]).to_f - spot.to_f }

          atm_strike = (atm[:strike] || atm["strike"]).to_f

          short_ce = ce_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike + wing)).abs < 0.001 }
          long_ce = ce_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike + (wing * 2))).abs < 0.001 }
          short_pe = pe_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike - wing)).abs < 0.001 }
          long_pe = pe_options.find { |o| ((o[:strike] || o["strike"]).to_f - (atm_strike - (wing * 2))).abs < 0.001 }

          raise ArgumentError, "Could not build iron condor — insufficient strikes in chain" unless short_ce && long_ce && short_pe && long_pe

          ctx[:legs] = [
            { action: DhanHQ::Constants::TransactionType::SELL, option_type: "CE", strike: atm_strike + wing, security_id: short_ce[:security_id] || short_ce["securityId"] },
            { action: DhanHQ::Constants::TransactionType::BUY, option_type: "CE", strike: atm_strike + (wing * 2), security_id: long_ce[:security_id] || long_ce["securityId"] },
            { action: DhanHQ::Constants::TransactionType::SELL, option_type: "PE", strike: atm_strike - wing, security_id: short_pe[:security_id] || short_pe["securityId"] },
            { action: DhanHQ::Constants::TransactionType::BUY, option_type: "PE", strike: atm_strike - (wing * 2), security_id: long_pe[:security_id] || long_pe["securityId"] }
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
