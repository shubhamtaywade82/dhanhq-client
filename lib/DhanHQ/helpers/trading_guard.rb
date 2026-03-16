# frozen_string_literal: true

require_relative "../utils/network_inspector"

module DhanHQ
  # Shared mixin for order-placing resources.
  #
  # Provides two private helpers:
  #   - ensure_live_trading! — raises LiveTradingDisabledError unless ENV["LIVE_TRADING"]="true"
  #   - log_order_context    — emits a structured JSON WARN log capturing machine/network context
  #
  # Include in any resource that writes to the exchange (create, update, cancel, configure, stop).
  module TradingGuard
    private

    # Raises LiveTradingDisabledError unless ENV["LIVE_TRADING"]="true".
    # Call this as the first line of any mutating method that touches live orders.
    def ensure_live_trading!
      return if ENV["LIVE_TRADING"] == "true"

      raise DhanHQ::LiveTradingDisabledError,
            "Live trading is disabled. Set ENV[\"LIVE_TRADING\"]=\"true\" to enable order placement."
    end

    # Emits a structured JSON WARN log with machine/network/correlation context.
    #
    # @param event  [String] Audit event label, e.g. "DHAN_ORDER_ATTEMPT"
    # @param params [Hash]   Request params (accepts both camelCase and snake_case keys)
    def log_order_context(event, params = {})
      inspector = DhanHQ::Utils::NetworkInspector
      entry = {
        event: event,
        hostname: inspector.hostname,
        env: inspector.environment,
        ipv4: inspector.public_ipv4,
        ipv6: inspector.public_ipv6,
        security_id: params[:securityId] || params["securityId"] ||
                     params[:security_id] || params["security_id"],
        correlation_id: params[:correlationId] || params["correlationId"] ||
                        params[:correlation_id] || params["correlation_id"],
        order_id: params[:orderId] || params["orderId"] ||
                  params[:order_id] || params["order_id"],
        timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
      }.compact

      DhanHQ.logger&.warn(JSON.generate(entry))
    end
  end
end
