# frozen_string_literal: true

module DhanHQ
  module Risk
    # Pre-execution risk pipeline that validates orders before they reach the broker.
    #
    # Runs a sequence of checks against the instrument and order arguments.
    # Raises DhanHQ::RiskViolation on the first failure.
    #
    # Open positions are fetched once per run and shared by every check. Orders that
    # only reduce an open position (see {Exposure.reducing?}) skip the limit checks
    # but still get the validity checks (trading permission, product support, order
    # type, quantity > 0, market hours).
    #
    # @example Run equity risk checks
    #   DhanHQ::Risk::Pipeline.run!(
    #     instrument: instrument,
    #     args: args,
    #     now: Time.now,
    #     type: :equity
    #   )
    #
    # @example Run options risk checks
    #   DhanHQ::Risk::Pipeline.run!(
    #     instrument: instrument,
    #     args: args,
    #     now: Time.now,
    #     type: :options
    #   )
    #
    class Pipeline
      CHECKS = [
        Checks::TradingPermission,
        Checks::AsmGsm,
        Checks::ProductSupport,
        Checks::OrderType,
        Checks::Quantity,
        Checks::MarketHours,
        Checks::PositionLimits,
        Checks::Concentration
      ].freeze

      OPTION_CHECKS = [
        Checks::Options
      ].freeze

      DAILY_CHECKS = [
        Checks::MaxLoss
      ].freeze

      # Run all applicable risk checks.
      #
      # @param instrument [Object] instrument with trading metadata
      # @param args [Hash] order arguments (snake_case string keys)
      # @param now [Time] current time for market hours check (default: Time.now)
      # @param type [Symbol] :equity or :options
      # @param positions [Array, nil] open positions; fetched once when nil
      # @return [true] if all checks pass
      # @raise [DhanHQ::RiskViolation] on first failure
      def self.run!(instrument:, args:, now: Time.now, type: :equity, positions: nil)
        positions ||= DhanHQ::Models::Position.all
        context = { instrument: instrument, args: args, now: now, positions: positions,
                    reducing: Exposure.reducing?(args, positions) }

        run_checks!(CHECKS, context)
        run_checks!(OPTION_CHECKS, context) if type == :options
        run_checks!(DAILY_CHECKS, context)
        true
      end

      def self.run_checks!(checks, context)
        checks.each { |check| check.run!(**context) }
      end

      private_class_method :run_checks!
    end
  end
end
