# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to build a long straddle (buy ATM call + buy ATM put).
      #
      # Steps: find instrument → spot price → option chain →
      # select ATM strikes → build intent.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("straddle",
      #     symbol: "NIFTY",
      #     expiry: "2026-01-30",
      #     quantity: 25
      #   )
      #
      class Straddle < Base
        risk "trade_adjacent_read"
        scope "orders:read"

        param :symbol, type: :string, required: true
        param :expiry, type: :string, required: true
        param :quantity, type: :integer, default: 25
        param :stop_loss, type: :number, default: 300
        param :target, type: :number, default: 600

        step :find_instrument, priority: 1
        step :get_spot_price, priority: 2
        step :get_option_chain, priority: 3
        step :select_atm_strikes, priority: 4
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

        def select_atm_strikes(ctx)
          spot = ctx[:spot_price].to_f
          chain = ctx[:chain]

          ce_options = chain.select { |o| (o[:option_type] || o["optionType"]) == "CE" }
          pe_options = chain.select { |o| (o[:option_type] || o["optionType"]) == "PE" }

          atm_ce = ce_options.min_by { |o| ((o[:strike] || o["strike"]).to_f - spot).abs }
          atm_pe = pe_options.min_by { |o| ((o[:strike] || o["strike"]).to_f - spot).abs }

          raise ArgumentError, "Could not find ATM CE strike" unless atm_ce
          raise ArgumentError, "Could not find ATM PE strike" unless atm_pe

          ctx[:atm_strike] = atm_ce[:strike] || atm_ce["strike"]
          ctx[:ce_security_id] = atm_ce[:security_id] || atm_ce["securityId"]
          ctx[:pe_security_id] = atm_pe[:security_id] || atm_pe["securityId"]
          ctx[:ce_premium] = atm_ce[:last_price] || atm_ce["lastPrice"] || atm_ce[:ltp] || atm_ce["ltp"]
          ctx[:pe_premium] = atm_pe[:last_price] || atm_pe["lastPrice"] || atm_pe[:ltp] || atm_pe["ltp"]
          ctx[:total_premium] = ctx[:ce_premium].to_f + ctx[:pe_premium].to_f
          ctx
        end

        def build_intent(ctx)
          ctx[:intent] = {
            trade_type: "STRADDLE",
            symbol: ctx[:symbol],
            expiry: ctx[:expiry],
            quantity: ctx[:quantity],
            legs: [
              { action: DhanHQ::Constants::TransactionType::BUY, option_type: "CE", strike: ctx[:atm_strike], security_id: ctx[:ce_security_id], premium: ctx[:ce_premium] },
              { action: DhanHQ::Constants::TransactionType::BUY, option_type: "PE", strike: ctx[:atm_strike], security_id: ctx[:pe_security_id], premium: ctx[:pe_premium] }
            ],
            total_premium: ctx[:total_premium],
            break_even_upside: ctx[:atm_strike].to_f + ctx[:total_premium],
            break_even_downside: ctx[:atm_strike].to_f - ctx[:total_premium],
            stop_loss: ctx[:stop_loss],
            target: ctx[:target],
            note: "Long straddle prepared. Await human confirmation."
          }
          ctx
        end
      end
    end
  end
end
