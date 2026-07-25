# frozen_string_literal: true

require_relative "../../concerns/order_audit"

module DhanHQ
  module Resources
    module GlobalStocks
      # Resource client for the Global Stocks (US equities) order endpoints.
      #
      #   POST   /v2/globalstocks/orders
      #   PUT    /v2/globalstocks/orders/{order-id}
      #   DELETE /v2/globalstocks/orders/{order-id}
      #   GET    /v2/globalstocks/orders
      #   GET    /v2/globalstocks/orders/{order-id}
      #
      # Writes go through the same {DhanHQ::Concerns::OrderAudit} guardrails as
      # domestic orders: +ENV["LIVE_TRADING"]="true"+ is required, and every attempt
      # emits a structured audit log line.
      #
      # The pre-trade {DhanHQ::Risk::Pipeline} is intentionally *not* run here. Its
      # checks (lot-size multiples, ASM/GSM surveillance lists, F&O product support,
      # NSE/BSE market hours) resolve instruments from the Indian scrip master, which
      # does not contain US securities.
      #
      # @see https://dhanhq.co/docs/v2/ Global Stocks section
      class Orders < BaseAPI
        include DhanHQ::Concerns::OrderAudit

        API_TYPE = :order_api
        HTTP_PATH = "/v2/globalstocks/orders"

        # Places a new Global Stocks order.
        #
        # @param params [Hash] Order attributes in snake_case. See
        #   {DhanHQ::Contracts::GlobalStocksPlaceOrderContract} for the accepted keys.
        # @return [Hash] `{ orderId:, orderStatus: }`
        # @raise [DhanHQ::LiveTradingDisabledError] Unless LIVE_TRADING is enabled.
        # @raise [DhanHQ::ValidationError] When the payload fails validation.
        def create(params)
          ensure_live_trading!
          log_order_context("DHAN_GLOBAL_ORDER_ATTEMPT", params)
          validate_place_order!(params)
          post("", params: params)
        end

        # Modifies a pending Global Stocks order.
        #
        # @param order_id [String]
        # @param params [Hash] Fields to change, in snake_case.
        # @return [Hash] `{ orderId:, orderStatus: }`
        def update(order_id, params)
          ensure_live_trading!
          log_order_context("DHAN_GLOBAL_ORDER_MODIFY_ATTEMPT", params.merge(order_id: order_id))
          validate_modify_order!(params.merge(order_id: order_id))
          put("/#{order_id}", params: params)
        end

        # Cancels a pending Global Stocks order.
        #
        # @param order_id [String]
        # @return [Hash] `{ orderId:, orderStatus: }`
        def cancel(order_id)
          ensure_live_trading!
          log_order_context("DHAN_GLOBAL_ORDER_CANCEL_ATTEMPT", { order_id: order_id })
          delete("/#{order_id}")
        end

        # Retrieves the current trading day's Global Stocks order book.
        #
        # @return [Array<Hash>]
        def all
          get("")
        end

        # Retrieves a single Global Stocks order by its Dhan order id.
        #
        # @param order_id [String]
        # @return [Hash]
        def find(order_id)
          get("/#{order_id}")
        end

        private

        def validate_place_order!(params)
          result = Contracts::GlobalStocksPlaceOrderContract.new.call(coerce_for_validation(params))
          raise_validation_error!(result) unless result.success?
        end

        def validate_modify_order!(params)
          result = Contracts::GlobalStocksModifyOrderContract.new.call(coerce_for_validation(params))
          raise_validation_error!(result) unless result.success?
        end

        # Global Stocks quantities and prices are floats (fractional shares are
        # supported), so integers handed in by callers are widened before validation.
        def coerce_for_validation(params)
          snake_case(params).each_with_object({}) do |(key, value), out|
            out[key] = FLOAT_KEYS.include?(key) && value.is_a?(Integer) ? value.to_f : value
          end
        end

        FLOAT_KEYS = %i[quantity price trigger_price stop_loss_price target_price amount].freeze
        private_constant :FLOAT_KEYS

        def raise_validation_error!(result)
          raise DhanHQ::ValidationError, "Invalid parameters: #{result.errors.to_h}"
        end
      end
    end
  end
end
