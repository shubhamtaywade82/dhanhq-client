# frozen_string_literal: true

module DhanHQ
  module Skills
    module Builtin
      # Skill to exit all open positions at market price.
      #
      # Steps: fetch positions → exit each position → summarize results.
      #
      # @example
      #   result = DhanHQ::Skills::Registry.call("square_off_all")
      #   puts result[:exited_count]
      #
      class SquareOffAll < Base
        risk "destructive_write"
        scope "orders:write"
        description "Exit all open positions at market price."

        step :fetch_positions, priority: 1
        step :exit_positions, priority: 2

        def fetch_positions(ctx)
          ctx[:positions] = DhanHQ::Models::Position.all.reject { |p| p.net_qty.to_i.zero? }
          ctx
        end

        def exit_positions(ctx)
          results = ctx[:positions].map do
            DhanHQ::Models::Position.exit_all!
          rescue StandardError => e
            { error: e.message }
          end

          ctx[:exit_results] = results
          ctx[:exited_count] = results.count { |r| !(r.is_a?(Hash) && r.key?(:error)) }
          ctx[:failed_count] = results.count { |r| r.is_a?(Hash) && r.key?(:error) }
          ctx
        end
      end
    end
  end
end
