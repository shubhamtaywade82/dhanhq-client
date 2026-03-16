# frozen_string_literal: true

require_relative "../utils/network_inspector"

module DhanHQ
  module Concerns
    # Shared behavior for order audit logging and live trading safety.
    #
    # Include this module in any Resource that submits, modifies, or cancels
    # orders on the Dhan API. It provides:
    #
    # - {#log_order_context}: emits a structured JSON log line (WARN level)
    #   capturing hostname, public IP, environment, security_id, correlation_id,
    #   and a UTC timestamp.
    #
    # - {#ensure_live_trading!}: raises {DhanHQ::LiveTradingDisabledError}
    #   unless +ENV["LIVE_TRADING"]+ is +"true"+, preventing accidental order
    #   placement from development machines.
    #
    # @example Including in a resource
    #   class MyOrders < BaseAPI
    #     include DhanHQ::Concerns::OrderAudit
    #
    #     def create(params)
    #       ensure_live_trading!
    #       log_order_context("MY_ORDER_ATTEMPT", params)
    #       post("", params: params)
    #     end
    #   end
    module OrderAudit
      private

      # Raises an error if LIVE_TRADING is not explicitly enabled.
      # Set ENV["LIVE_TRADING"]="true" in production to allow order submission.
      def ensure_live_trading!
        return if ENV["LIVE_TRADING"] == "true"

        raise DhanHQ::LiveTradingDisabledError,
              "Live trading is disabled. Set ENV[\"LIVE_TRADING\"]=\"true\" to enable order placement."
      end

      # Emits a structured JSON log line with machine/network/correlation context.
      # Uses WARN level so it appears even when INFO is silenced.
      def log_order_context(event, params)
        inspector = DhanHQ::Utils::NetworkInspector
        entry = {
          event: event,
          hostname: inspector.hostname,
          env: inspector.environment,
          ipv4: inspector.public_ipv4,
          ipv6: inspector.public_ipv6,
          security_id: extract_param(params, :securityId, :security_id),
          correlation_id: extract_param(params, :correlationId, :correlation_id),
          order_id: extract_param(params, :orderId, :order_id),
          timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        }.compact

        DhanHQ.logger&.warn(JSON.generate(entry))
      end

      # Extracts a value from params trying both camelCase and snake_case keys,
      # as well as both symbol and string key types.
      def extract_param(params, camel_key, snake_key)
        params[camel_key] || params[camel_key.to_s] ||
          params[snake_key] || params[snake_key.to_s]
      end
    end
  end
end
