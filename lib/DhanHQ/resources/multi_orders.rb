# frozen_string_literal: true

require_relative "../concerns/order_audit"

module DhanHQ
  module Resources
    # Resource for basket orders: POST /v2/alerts/multi/orders.
    #
    # Places up to {DhanHQ::Contracts::MultiOrderContract::MAX_ORDERS} unconditional
    # orders in a single request. Unlike {AlertOrders} there is no trigger condition —
    # every leg is sent to the exchange immediately.
    #
    # @see https://dhanhq.co/docs/v2/ Conditional and Multi Order section
    class MultiOrders < BaseAPI
      include DhanHQ::Concerns::OrderAudit

      API_TYPE  = :order_api
      HTTP_PATH = "/v2/alerts/multi/orders"

      # Places a basket of orders.
      #
      # @param orders [Array<Hash>] Order legs in snake_case. Each leg requires
      #   +:sequence+, +:transaction_type+ and +:exchange_segment+.
      # @param dhan_client_id [String, nil] Defaults to the configured client id.
      # @return [Hash] `{ orders: [{ orderId:, sequence:, orderStatus: }, ...] }`
      # @raise [DhanHQ::LiveTradingDisabledError] Unless LIVE_TRADING is enabled.
      # @raise [DhanHQ::ValidationError] When any leg fails validation.
      def create(orders, dhan_client_id: nil)
        ensure_live_trading!

        legs = Array(orders).map { |leg| snake_case(leg) }
        payload = { dhan_client_id: dhan_client_id || DhanHQ.configuration&.client_id, orders: legs }.compact

        validate!(payload)
        legs.each { |leg| run_risk_checks!(leg) }
        log_multi_order_context(legs)

        post("", params: payload)
      end

      private

      def validate!(payload)
        result = Contracts::MultiOrderContract.new.call(payload)
        raise DhanHQ::ValidationError, "Invalid parameters: #{result.errors.to_h}" unless result.success?
      end

      # Emits one audit line per leg so each order in the basket is traceable.
      def log_multi_order_context(legs)
        legs.each do |leg|
          log_order_context("DHAN_MULTI_ORDER_ATTEMPT", leg)
        end
      end
    end
  end
end
