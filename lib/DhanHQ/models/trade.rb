# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Represents a single trade.
    # The API docs show an array of trades from GET /v2/trades/{from-date}/{to-date}/{page}
    class Trade < BaseModel
      # No explicit HTTP_PATH if we rely on the statements resource
      # but we can define it if needed
      HTTP_PATH = "/v2/trades"

      attributes :dhan_client_id, :order_id, :exchange_order_id, :exchange_trade_id,
                 :transaction_type, :exchange_segment, :product_type, :order_type,
                 :trading_symbol, :custom_symbol, :security_id, :traded_quantity,
                 :traded_price, :isin, :instrument, :sebi_tax, :stt, :brokerage_charges,
                 :service_tax, :exchange_transaction_charges, :stamp_duty,
                 :create_time, :update_time, :exchange_time, :drv_expiry_date,
                 :drv_option_type, :drv_strike_price

      class << self
        ##
        # Provide a **shared instance** of the `Statements` resource,
        # where we have `trade_history(from_date:, to_date:, page:)`.
        def resource
          @resource ||= DhanHQ::Resources::Statements.new
        end

        ##
        # Fetch trades within the given date range and page.
        # GET /v2/trades/{from-date}/{to-date}/{page}
        #
        # @param from_date [String]
        # @param to_date   [String]
        # @param page      [Integer] Default 0
        # @return [Array<Trade>]
        def all(from_date:, to_date:, page: 0)
          # The resource call returns an Array<Hash>.
          response = resource.trade_history(from_date: from_date, to_date: to_date, page: page)
          return [] unless response.is_a?(Array)

          response.map do |t|
            new(t, skip_validation: true)
          end
        end
      end

      # e.g. #to_h override if desired
      def to_h
        {
          order_id: order_id,
          exchange_order_id: exchange_order_id,
          traded_quantity: traded_quantity,
          traded_price: traded_price
          # ... etc.
        }
      end

      # If you want custom validations, you'd set a contract or skip for read-only
      def validation_contract
        nil
      end
    end
  end
end
