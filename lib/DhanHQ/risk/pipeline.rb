# frozen_string_literal: true

module DhanHQ
  module Risk
    # Pre-execution risk pipeline that validates orders before they reach the broker.
    #
    # Runs a sequence of checks against the instrument and order arguments.
    # Raises DhanHQ::RiskViolation on the first failure.
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
      # @param args [Hash] order arguments (string keys)
      # @param now [Time] current time for market hours check (default: Time.now)
      # @param type [Symbol] :equity or :options
      # @return [true] if all checks pass
      # @raise [DhanHQ::RiskViolation] on first failure
      # rubocop:disable Naming/PredicateMethod
      def self.run!(instrument:, args:, now: Time.now, type: :equity)
        run_checks!(CHECKS, instrument, args, now)
        run_checks!(OPTION_CHECKS, instrument, args, now) if type == :options
        run_checks!(DAILY_CHECKS, instrument, args, now)
        true
      end
      # rubocop:enable Naming/PredicateMethod

      def self.run_checks!(checks, instrument, args, now)
        checks.each do |check|
          check.run!(instrument: instrument, args: args, now: now)
        end
      end

      private_class_method :run_checks!
    end
  end
end
