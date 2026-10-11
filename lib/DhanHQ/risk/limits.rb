# frozen_string_literal: true

module DhanHQ
  module Risk
    # Configurable thresholds for the pre-trade risk checks.
    #
    # Each check keeps its historical constant as the default, so an unconfigured
    # client behaves exactly as before. Override per process with
    # {DhanHQ::Configuration#risk_limits} or the matching +DHAN_RISK_*+ variable:
    #
    #   DhanHQ.configure do |c|
    #     c.risk_limits = { max_quantity: 1_800, max_notional: 250_000 }
    #   end
    #
    # +max_quantity+ is in units as sent to the API (one NIFTY lot is 75 units),
    # not in lots.
    module Limits
      # Limit name => environment variable that sets it.
      ENV_KEYS = {
        max_quantity: "DHAN_RISK_MAX_QUANTITY",
        max_notional: "DHAN_RISK_MAX_NOTIONAL",
        max_open_positions: "DHAN_RISK_MAX_OPEN_POSITIONS",
        daily_max_loss: "DHAN_RISK_DAILY_MAX_LOSS",
        max_concentration_pct: "DHAN_RISK_MAX_CONCENTRATION_PCT"
      }.freeze

      # Every limit name {DhanHQ::Configuration#risk_limits} accepts.
      NAMES = ENV_KEYS.keys.freeze

      # @param name [Symbol] One of {NAMES}.
      # @param default [Numeric] The check's built-in threshold.
      # @return [Numeric] The configured threshold, or +default+.
      def self.value(name, default)
        DhanHQ.configuration&.risk_limits&.fetch(name, nil) || default
      end

      # Validates and normalises a limits hash (String or Symbol keys, numeric values).
      #
      # @param raw [Hash, nil]
      # @return [Hash{Symbol => Numeric}]
      # @raise [ArgumentError] On an unknown name or a non-positive / non-numeric value.
      def self.coerce(raw)
        return {} if raw.nil?
        raise ArgumentError, "risk_limits must be a Hash of #{NAMES.join(", ")}" unless raw.is_a?(Hash)

        raw.each_with_object({}) do |(name, value), out|
          key = name.to_s.strip.to_sym
          raise ArgumentError, "unknown risk limit #{name.inspect}: expected one of #{NAMES.join(", ")}" unless NAMES.include?(key)

          out[key] = positive_number!(key, value)
        end
      end

      # Limits set through +DHAN_RISK_*+ environment variables.
      #
      # @return [Hash{Symbol => Numeric}]
      def self.from_env
        coerce(ENV_KEYS.each_with_object({}) do |(name, env), out|
          raw = ENV.fetch(env, "").strip
          out[name] = raw unless raw.empty?
        end)
      end

      def self.positive_number!(key, value)
        number = Float(value.to_s, exception: false)
        raise ArgumentError, "risk limit #{key} must be a number (got #{value.inspect})" if number.nil?
        raise ArgumentError, "risk limit #{key} must be positive (got #{value.inspect})" unless number.positive?

        (number % 1).zero? ? number.to_i : number
      end

      private_class_method :positive_number!
    end
  end
end
