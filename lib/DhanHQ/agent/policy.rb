# frozen_string_literal: true

module DhanHQ
  module Agent
    # Permission policy for MCP and agent-skill integrations.
    class Policy
      READ_SCOPES = %w[portfolio:read market:read orders:read].freeze
      WRITE_SCOPES = %w[orders:write orders:cancel alerts:write risk:write].freeze
      ALL_SCOPES = (READ_SCOPES + WRITE_SCOPES).freeze

      attr_reader :scopes

      def initialize(scopes: [])
        @scopes = Array(scopes).map(&:to_s).uniq.freeze
        unknown = @scopes - ALL_SCOPES
        raise ArgumentError, "Unknown agent scopes: #{unknown.join(", ")}" if unknown.any?
      end

      def self.read_only
        new(scopes: READ_SCOPES)
      end

      def self.from_env
        raw = ENV.fetch("DHANHQ_AGENT_SCOPES", READ_SCOPES.join(","))
        new(scopes: raw.split(/[\s,]+/).reject(&:empty?))
      end

      def allow?(scope)
        @scopes.include?(scope.to_s)
      end

      def require!(scope)
        return true if allow?(scope)

        raise DhanHQ::Error, "Agent scope required: #{scope}"
      end

      def writes_enabled?
        ENV["DHANHQ_MCP_ENABLE_WRITES"] == "true" && ENV["LIVE_TRADING"] == "true"
      end

      def require_write!(scope)
        require!(scope)
        return true if writes_enabled?

        raise DhanHQ::LiveTradingDisabledError,
              "Agent write tools require DHANHQ_MCP_ENABLE_WRITES=true and LIVE_TRADING=true"
      end
    end
  end
end
