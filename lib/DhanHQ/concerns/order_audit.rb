# frozen_string_literal: true

require_relative "../utils/network_inspector"

module DhanHQ
  module Concerns
    # Shared behavior for order audit logging, live trading safety, and
    # pre-trade risk checks.
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
    # - {#run_risk_checks!}: runs {DhanHQ::Risk::Pipeline} against the order
    #   params before execution.  Catches unresolvable instruments and other
    #   edge cases silently so the risk layer never blocks a valid order due
    #   to a transient lookup failure.
    #
    # @example Including in a resource
    #   class MyOrders < BaseAPI
    #     include DhanHQ::Concerns::OrderAudit
    #
    #     def create(params)
    #       ensure_live_trading!
    #       run_risk_checks!(params)
    #       log_order_context("MY_ORDER_ATTEMPT", params)
    #       post("", params: params)
    #     end
    #   end
    module OrderAudit
      private

      # Raises an error unless live trading is explicitly enabled OR the request
      # targets the sandbox host, where no real money is at risk.
      #
      # Set ENV["LIVE_TRADING"]="true" to allow order submission against the
      # production host. Orders routed to the sandbox host (config.mode =
      # :sandbox, or the trading tiers under :hybrid) skip the gate because they
      # cannot place real orders.
      def ensure_live_trading!
        return if ENV["LIVE_TRADING"] == "true"
        return if sandbox_target?

        raise DhanHQ::LiveTradingDisabledError,
              "Live trading is disabled. Set ENV[\"LIVE_TRADING\"]=\"true\" to enable order placement, " \
              "or switch to the sandbox with DhanHQ.configure { |c| c.mode = :sandbox } / :hybrid."
      end

      # True when this resource's requests resolve to the sandbox host.
      # Tolerates hosts that never got a client wired in (bare test doubles).
      def sandbox_target?
        return false unless respond_to?(:client) && client.respond_to?(:environment)

        client.environment == :sandbox
      end

      # Runs the risk pipeline for the given order params.
      #
      # Extracts +security_id+ and +exchange_segment+ from the params,
      # resolves the instrument, and calls {DhanHQ::Risk::Pipeline.run!}.
      # If the instrument cannot be resolved the check is skipped rather than
      # blocking the order, since a transient scrip-master lookup failure should not
      # stop a valid trade.
      #
      # Anything other than a lookup failure is logged before being swallowed. This
      # method used to rescue StandardError silently, which is how a wrong-arity call
      # to `Instrument.find` went unnoticed long enough for the risk pipeline to never
      # run for any real order (see CHANGELOG 3.1.0). A skipped check is tolerable; a
      # skipped check nobody can see is not.
      def run_risk_checks!(params)
        security_id = extract_param(params, :securityId, :security_id)
        exchange_segment = extract_param(params, :exchangeSegment, :exchange_segment)
        return unless security_id && exchange_segment

        instrument = resolve_instrument_for_risk(exchange_segment, security_id)
        return unless instrument

        DhanHQ::Risk::Pipeline.run!(
          instrument: instrument,
          args: risk_args(params),
          type: trade_type_for(exchange_segment),
          now: Time.now
        )
      rescue DhanHQ::RiskViolation
        raise
      rescue StandardError => e
        log_risk_check_skipped(e, security_id, exchange_segment)
        nil
      end

      # Resolves the instrument the risk pipeline needs, tolerating a lookup failure.
      #
      # @return [DhanHQ::Models::Instrument, nil]
      def resolve_instrument_for_risk(exchange_segment, security_id)
        DhanHQ::Models::Instrument.find_by_security_id(exchange_segment, security_id)
      rescue StandardError => e
        log_risk_check_skipped(e, security_id, exchange_segment)
        nil
      end

      # Records that pre-trade risk checks did not run, and why.
      def log_risk_check_skipped(error, security_id, exchange_segment)
        DhanHQ.logger&.error(
          JSON.generate(
            event: "DHAN_RISK_CHECK_SKIPPED",
            security_id: security_id,
            exchange_segment: exchange_segment,
            error: error.class.name,
            message: error.message
          )
        )
      end

      # The risk checks read snake_case String keys ("quantity", "order_type", ...).
      # Order params arrive as camelCase Strings from the models and as Symbols or
      # Strings from direct resource callers; without this, every check that reads a
      # multi-word key silently saw nil, and Symbol-keyed callers failed
      # "Quantity must be > 0" on a valid quantity.
      #
      # @param params [Hash]
      # @return [Hash{String => Object}]
      def risk_args(params)
        (params || {}).to_h.transform_keys { |key| key.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase }
      end

      # Maps an exchange segment string to a pipeline trade type.
      def trade_type_for(exchange_segment)
        case exchange_segment.to_s
        when /^NSE_FNO/, /^BSE_FNO/, /^NSE_CURRENCY/, /^BSE_CURRENCY/ then :fno
        when /^MCX/ then :commodity
        else :equity
        end
      end

      # Emits a structured JSON log line with machine/network/correlation context.
      # Uses WARN level so it appears even when INFO is silenced.
      def log_order_context(event, params = {})
        inspector = DhanHQ::Utils::NetworkInspector
        entry = {
          event: event,
          hostname: inspector.hostname,
          env: inspector.environment,
          target: request_target,
          ipv4: inspector.public_ipv4,
          ipv6: inspector.public_ipv6,
          security_id: extract_param(params, :securityId, :security_id),
          correlation_id: extract_param(params, :correlationId, :correlation_id),
          order_id: extract_param(params, :orderId, :order_id),
          timestamp: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        }.compact

        DhanHQ.logger&.warn(JSON.generate(entry))
      end

      # The host the order will be sent to, for the audit trail.
      def request_target
        return "sandbox" if sandbox_target?

        "live"
      end

      # Extracts a value from params trying both camelCase and snake_case keys,
      # as well as both symbol and string key types.
      def extract_param(params, camel_key, snake_key)
        p = params || {}
        p[camel_key] || p[camel_key.to_s] || p[snake_key] || p[snake_key.to_s]
      end
    end
  end
end
