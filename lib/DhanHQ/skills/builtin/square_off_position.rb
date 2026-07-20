# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to exit a specific position by symbol.
      #
      # Steps: find position → exit position → return result.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("square_off_position",
      #     symbol: "NIFTY",
      #     exchange_segment: "IDX_I"
      #   )
      #
      class SquareOffPosition < Base
        risk "destructive_write"
        scope "orders:write"
        description "Exit a specific open position by symbol and exchange segment."

        param :symbol, type: :string, required: true
        param :exchange_segment, type: :string, required: true

        step :find_position, priority: 1
        step :exit_position, priority: 2

        def find_position(ctx)
          positions = DhanHQ::Models::Position.all
          target = positions.find do |p|
            seg = p[:exchange_segment] || p["exchange_segment"]
            sym = p[:trading_symbol] || p["tradingSymbol"] || p[:symbol] || p["symbol"]
            seg.to_s == ctx[:exchange_segment].to_s && sym.to_s.upcase == ctx[:symbol].to_s.upcase
          end

          raise ArgumentError, "No open position found for #{ctx[:symbol]} on #{ctx[:exchange_segment]}" unless target

          ctx[:position] = target
          ctx[:security_id] = target[:security_id] || target["securityId"]
          ctx[:trading_symbol] = target[:trading_symbol] || target["tradingSymbol"]
          ctx[:net_quantity] = (target[:net_quantity] || target["netQuantity"] || target.net_quantity).to_i
          ctx
        end

        def exit_position(ctx)
          ctx[:exit_result] = DhanHQ::Models::Position.exit_all!
          ctx[:exited] = true
          ctx
        end
      end
    end
  end
end
