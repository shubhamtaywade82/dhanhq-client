# frozen_string_literal: true

require_relative "../utils/network_inspector"

module DhanHQ
  module Resources
    # Handles order placement, modification, and cancellation
    class Orders < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/orders"

      # --------------------------------------------------
      # PUBLIC API
      # --------------------------------------------------

      def create(params)
        ensure_live_trading!
        log_order_context("DHAN_ORDER_ATTEMPT", params)
        validate_place_order!(params)
        post("", params: params)
      end

      def update(order_id, params)
        log_order_context("DHAN_ORDER_MODIFY_ATTEMPT", params.merge(order_id: order_id))
        validate_modify_order!(params.merge(order_id: order_id))
        put("/#{order_id}", params: params)
      end

      def slicing(params)
        ensure_live_trading!
        log_order_context("DHAN_ORDER_SLICING_ATTEMPT", params)
        validate_place_order!(params)
        post("/slicing", params: params)
      end

      def cancel(order_id)
        delete("/#{order_id}")
      end

      def all
        get("")
      end

      def find(order_id)
        get("/#{order_id}")
      end

      def by_correlation(correlation_id)
        get("/external/#{correlation_id}")
      end

      # --------------------------------------------------
      # VALIDATION LAYER
      # --------------------------------------------------

      private

      def validate_place_order!(params)
        result = Contracts::PlaceOrderContract.new.call(normalize_keys_for_validation(params))
        raise_validation_error!(result) unless result.success?
      end

      def validate_modify_order!(params)
        result = Contracts::ModifyOrderContract.new.call(normalize_keys_for_validation(params))
        raise_validation_error!(result) unless result.success?
      end

      def normalize_keys_for_validation(params)
        snake_case(params)
      end

      def raise_validation_error!(result)
        raise DhanHQ::ValidationError, "Invalid parameters: #{result.errors.to_h}"
      end

      # --------------------------------------------------
      # LIVE TRADING GUARD
      # --------------------------------------------------

      # Raises an error if LIVE_TRADING is not explicitly enabled.
      # Set ENV["LIVE_TRADING"]="true" in production to allow order submission.
      def ensure_live_trading!
        return if ENV["LIVE_TRADING"] == "true"

        raise DhanHQ::LiveTradingDisabledError,
              "Live trading is disabled. Set ENV[\"LIVE_TRADING\"]=\"true\" to enable order placement."
      end

      # --------------------------------------------------
      # ORDER AUDIT LOGGING
      # --------------------------------------------------

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
end
