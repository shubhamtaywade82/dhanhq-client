# frozen_string_literal: true

module DhanHQ
  module Agent
    # Dry-run order validator and human-readable summary for agent workflows.
    class OrderPreview
      attr_reader :params, :errors

      def initialize(params)
        @params = DhanHQ::Agent::ToolRegistry.symbolize(params)
        @errors = []
        validate
      end

      def valid?
        errors.empty?
      end

      def to_h
        {
          valid: valid?,
          errors: errors,
          action: "place_order",
          risk: "live_order_requires_confirmation",
          requires: %w[orders:write DHANHQ_MCP_ENABLE_WRITES LIVE_TRADING],
          summary: summary,
          order: params
        }
      end

      private

      def validate
        result = DhanHQ::Contracts::PlaceOrderContract.call(params)
        @errors << result.errors.to_h if result.failure?
        @errors << "correlation_id is recommended for agent-originated orders" if params[:correlation_id].to_s.empty?
      end

      def summary
        side = params[:transaction_type]
        qty = params[:quantity]
        security = params[:security_id]
        segment = params[:exchange_segment]
        type = params[:order_type]
        price = params[:price] ? " @ #{params[:price]}" : ""
        "#{side} #{qty} of #{segment}:#{security} as #{type}#{price}"
      end
    end
  end
end
