# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Handles order placement, modification, and cancellation
    class Orders < BaseAPI
      include DhanHQ::Concerns::OrderAudit

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
        ensure_live_trading!
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
        ensure_live_trading!
        log_order_context("DHAN_ORDER_CANCEL_ATTEMPT", { order_id: order_id })
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
    end
  end
end
