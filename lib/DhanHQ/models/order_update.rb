# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Represents a real-time order update received via WebSocket
    # Parses and provides access to all order update fields as per DhanHQ API documentation
    # rubocop:disable Metrics/ClassLength
    class OrderUpdate < BaseModel
      # All order update attributes as per API documentation
      attributes :exchange, :segment, :source, :security_id, :client_id,
                 :exch_order_no, :order_no, :product, :txn_type, :order_type,
                 :validity, :disc_quantity, :disc_qty_rem, :remaining_quantity,
                 :quantity, :traded_qty, :price, :trigger_price, :traded_price,
                 :avg_traded_price, :algo_ord_no, :off_mkt_flag, :order_date_time,
                 :exch_order_time, :last_updated_time, :remarks, :mkt_type,
                 :reason_description, :leg_no, :instrument, :symbol, :product_name,
                 :status, :lot_size, :strike_price, :expiry_date, :opt_type,
                 :display_name, :isin, :series, :good_till_days_date, :ref_ltp,
                 :tick_size, :algo_id, :multiplier, :correlation_id

      ##
      # Create OrderUpdate from WebSocket message
      # @param message [Hash] Raw WebSocket message
      # @return [OrderUpdate] Parsed order update
      def self.from_websocket_message(message)
        return nil unless message.is_a?(Hash) && message[:Type] == "order_alert"
        return nil unless message[:Data].is_a?(Hash)

        # Map the WebSocket message data to our attributes
        data = message[:Data]
        new(data, skip_validation: true)
      end

      ##
      # OrderUpdate objects are read-only, so no validation contract needed
      def validation_contract
        nil
      end

      ##
      # Helper methods for transaction type
      def buy?
        txn_type == "B"
      end

      def sell?
        txn_type == "S"
      end

      ##
      # Helper methods for order type
      def limit_order?
        order_type == "LMT"
      end

      def market_order?
        order_type == "MKT"
      end

      def stop_loss_order?
        order_type == "SL"
      end

      def stop_loss_market_order?
        order_type == "SLM"
      end

      ##
      # Helper methods for product type
      def cnc_product?
        product == "C"
      end

      def intraday_product?
        product == "I"
      end

      def margin_product?
        product == "M"
      end

      def mtf_product?
        product == "F"
      end

      def cover_order?
        product == "V"
      end

      def bracket_order?
        product == "B"
      end

      ##
      # Helper methods for order status
      def transit?
        status == "TRANSIT"
      end

      def pending?
        status == "PENDING"
      end

      def rejected?
        status == "REJECTED"
      end

      def cancelled?
        status == "CANCELLED"
      end

      def traded?
        status == "TRADED"
      end

      def expired?
        status == "EXPIRED"
      end

      ##
      # Helper methods for instrument type
      def equity?
        instrument == "EQUITY"
      end

      def derivative?
        instrument == "DERIVATIVES"
      end

      def option?
        %w[CE PE].include?(opt_type)
      end

      def call_option?
        opt_type == "CE"
      end

      def put_option?
        opt_type == "PE"
      end

      ##
      # Helper methods for order leg (for Super Orders)
      def entry_leg?
        leg_no == 1
      end

      def stop_loss_leg?
        leg_no == 2
      end

      def target_leg?
        leg_no == 3
      end

      ##
      # Helper methods for market type
      def normal_market?
        mkt_type == "NL"
      end

      def auction_market?
        %w[AU A1 A2].include?(mkt_type)
      end

      ##
      # Helper methods for order characteristics
      def amo_order?
        off_mkt_flag == "1"
      end

      def super_order?
        remarks == "Super Order"
      end

      def partially_executed?
        traded_qty.positive? && traded_qty < quantity
      end

      def fully_executed?
        traded_qty == quantity
      end

      def not_executed?
        traded_qty.zero?
      end

      ##
      # Calculation methods
      def execution_percentage
        return 0.0 if quantity.zero?

        (traded_qty.to_f / quantity * 100).round(2)
      end

      def pending_quantity
        quantity - traded_qty
      end

      def total_value
        return 0 unless traded_qty && avg_traded_price

        traded_qty * avg_traded_price
      end

      ##
      # Status summary for logging/debugging
      # rubocop:disable Metrics/MethodLength
      def status_summary
        {
          order_no: order_no,
          symbol: symbol,
          status: status,
          txn_type: txn_type,
          quantity: quantity,
          traded_qty: traded_qty,
          execution_percentage: execution_percentage,
          price: price,
          avg_traded_price: avg_traded_price,
          leg_no: leg_no,
          super_order: super_order?
        }
      end
      # rubocop:enable Metrics/MethodLength

      ##
      # Convert to hash for serialization
      def to_hash
        @attributes.dup
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
