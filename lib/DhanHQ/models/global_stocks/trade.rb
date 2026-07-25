# frozen_string_literal: true

module DhanHQ
  module Models
    module GlobalStocks
      ##
      # A single executed Global Stocks (US equity) trade.
      #
      # @example Today's US trades
      #   DhanHQ::Models::GlobalStocks::Trade.all.each do |t|
      #     puts "#{t.trading_symbol} #{t.traded_quantity} @ $#{t.traded_price}"
      #   end
      #
      # @example Trades for one symbol
      #   DhanHQ::Models::GlobalStocks::Trade.find_by_security_id("AAPL")
      #
      class Trade < BaseModel
        HTTP_PATH = "/v2/globalstocks/trades"

        attributes :dhan_client_id, :order_id, :exchange_order_id, :transaction_type,
                   :exchange_segment, :product_type, :order_type, :trading_symbol,
                   :security_id, :traded_quantity, :traded_price, :trade_date,
                   :create_time, :exchange_time, :order_status, :brokerage,
                   :other_charges, :trade_value

        # Returns a concise prompt-friendly summary of the trade.
        def to_prompt
          parts = ["#{transaction_type} #{traded_quantity}x #{trading_symbol || security_id}"]
          parts << "@ $#{traded_price}" if traded_price
          parts << "value=$#{trade_value}" if trade_value
          parts << "on #{trade_date}" if trade_date
          parts.join(", ")
        end

        # Total cost of the trade, brokerage and other charges combined.
        #
        # @return [Float]
        def total_charges
          brokerage.to_f + other_charges.to_f
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::Trades]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::Trades.new
          end

          # Retrieves the current trading day's executed Global Stocks trades.
          #
          # @return [Array<Trade>]
          def all
            build_collection(resource.all)
          end

          # Retrieves executed Global Stocks trades for a single security.
          #
          # @param security_id [String]
          # @return [Array<Trade>]
          def find_by_security_id(security_id)
            build_collection(resource.by_security_id(security_id))
          end

          private

          def build_collection(response)
            return [] unless response.is_a?(Array)

            response.map { |trade| new(trade, skip_validation: true) }
          end
        end
      end
    end
  end
end
