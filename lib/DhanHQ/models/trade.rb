# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Represents a single trade.
    # Supports three main API endpoints:
    # 1. GET /v2/trades - Current day trades
    # 2. GET /v2/trades/{order-id} - Trades for specific order
    # 3. GET /v2/trades/{from-date}/{to-date}/{page} - Historical trades
    class Trade < BaseModel
      HTTP_PATH = "/v2/trades"

      # All trade attributes as per API documentation
      attributes :dhan_client_id, :order_id, :exchange_order_id, :exchange_trade_id,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :trading_symbol, :custom_symbol, :security_id, :traded_quantity,
                 :traded_price, :isin, :instrument, :sebi_tax, :stt, :brokerage_charges,
                 :service_tax, :exchange_transaction_charges, :stamp_duty,
                 :create_time, :update_time, :exchange_time, :drv_expiry_date,
                 :drv_option_type, :drv_strike_price

      class << self
        ##
        # Resource for current day tradebook APIs
        def tradebook_resource
          @tradebook_resource ||= DhanHQ::Resources::Trades.new
        end

        ##
        # Resource for historical trade data
        def statements_resource
          @statements_resource ||= DhanHQ::Resources::Statements.new
        end

        ##
        # Fetch current day trades
        # GET /v2/trades
        #
        # @return [Array<Trade>] Array of trades executed today
        def today
          response = tradebook_resource.all
          return [] unless response.is_a?(Array)

          response.map { |trade_data| new(trade_data, skip_validation: true) }
        end

        ##
        # Fetch trades for a specific order ID (current day)
        # GET /v2/trades/{order-id}
        #
        # @param order_id [String] The order ID to fetch trades for
        # @return [Trade, nil] Trade object or nil if not found
        def find_by_order_id(order_id)
          # Validate input
          contract = DhanHQ::Contracts::TradeByOrderIdContract.new
          validation_result = contract.call(order_id: order_id)

          unless validation_result.success?
            raise DhanHQ::ValidationError, "Invalid order_id: #{validation_result.errors.to_h}"
          end

          response = tradebook_resource.find(order_id)
          return nil unless response.is_a?(Hash) || (response.is_a?(Array) && response.any?)

          data = response.is_a?(Array) ? response.first : response
          new(data, skip_validation: true)
        end

        ##
        # Fetch historical trades within the given date range and page
        # GET /v2/trades/{from-date}/{to-date}/{page}
        #
        # @param from_date [String] Start date in YYYY-MM-DD format
        # @param to_date   [String] End date in YYYY-MM-DD format
        # @param page      [Integer] Page number (default: 0)
        # @return [Array<Trade>] Array of historical trades
        def history(from_date:, to_date:, page: 0)
          validate_history_params(from_date, to_date, page)

          response = statements_resource.trade_history(
            from_date: from_date,
            to_date: to_date,
            page: page
          )

          return [] unless response.is_a?(Array)

          response.map { |trade_data| new(trade_data, skip_validation: true) }
        end

        private

        def validate_history_params(from_date, to_date, page)
          contract = DhanHQ::Contracts::TradeHistoryContract.new
          validation_result = contract.call(from_date: from_date, to_date: to_date, page: page)

          return if validation_result.success?

          raise DhanHQ::ValidationError, "Invalid parameters: #{validation_result.errors.to_h}"
        end

        # Alias for backward compatibility
        alias all history
      end

      ##
      # Trade objects are read-only, so no validation contract needed
      def validation_contract
        nil
      end

      ##
      # Helper methods for trade data
      def buy?
        transaction_type == "BUY"
      end

      def sell?
        transaction_type == "SELL"
      end

      def equity?
        instrument == "EQUITY"
      end

      def derivative?
        instrument == "DERIVATIVES"
      end

      def option?
        %w[CALL PUT].include?(drv_option_type)
      end

      def call_option?
        drv_option_type == "CALL"
      end

      def put_option?
        drv_option_type == "PUT"
      end

      ##
      # Calculate total trade value
      def total_value
        return 0 unless traded_quantity && traded_price

        traded_quantity * traded_price
      end

      ##
      # Calculate total charges
      def total_charges
        charges = [sebi_tax, stt, brokerage_charges, service_tax,
                   exchange_transaction_charges, stamp_duty].compact
        charges.sum(&:to_f)
      end

      ##
      # Net trade value after charges
      def net_value
        total_value - total_charges
      end
    end
  end
end
