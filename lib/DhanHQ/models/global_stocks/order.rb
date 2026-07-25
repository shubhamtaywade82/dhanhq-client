# frozen_string_literal: true

module DhanHQ
  module Models
    # Typed models for the Global Stocks (US equities) APIs.
    #
    # Global Stocks are a separate book from domestic NSE/BSE trading: separate
    # order book, holdings, trades and a USD fund limit. They are namespaced so
    # `Models::GlobalStocks::Holding` can never be confused with the domestic
    # {DhanHQ::Models::Holding}.
    module GlobalStocks
      ##
      # A single Global Stocks (US equity) order.
      #
      # @example Place a limit order for one share of AAPL
      #   order = DhanHQ::Models::GlobalStocks::Order.place(
      #     transaction_type: "BUY",
      #     order_type: "LIMIT",
      #     security_id: "AAPL",
      #     quantity: 1,
      #     price: 180.0
      #   )
      #   order.order_id # => "112111182198"
      #
      # @example Place a notional ($ value) order
      #   DhanHQ::Models::GlobalStocks::Order.place(
      #     transaction_type: "BUY",
      #     order_type: "AMOUNT",
      #     security_id: "AAPL",
      #     amount: 500.0
      #   )
      #
      # @example Fetch the order book
      #   DhanHQ::Models::GlobalStocks::Order.all.each do |o|
      #     puts "#{o.trading_symbol} #{o.order_status} #{o.traded_qty}/#{o.quantity}"
      #   end
      #
      class Order < BaseModel
        extend DhanHQ::Concerns::BangWrites
        extend DhanHQ::Concerns::TrackedWrites

        track_class_writes :place
        track_writes :modify, :cancel

        bang_class_writes :place
        bang_writes :modify, :cancel

        HTTP_PATH = "/v2/globalstocks/orders"

        attributes :dhan_client_id, :order_id, :exchange_order_id, :correlation_id,
                   :transaction_type, :exchange_segment, :product_type, :order_type,
                   :validity, :trading_symbol, :display_name, :security_id,
                   :quantity, :remaining_quantity, :traded_qty, :price, :trigger_price,
                   :avg_traded_price, :order_status, :create_time, :exchange_time,
                   :update_time, :oms_error_code, :oms_error_description,
                   :after_market_order, :amount, :lot_size, :fractional_flag,
                   :leg_name, :child_orders

        # Returns a concise prompt-friendly summary of the order.
        def to_prompt
          parts = ["#{transaction_type} #{quantity || amount}x #{trading_symbol || security_id}"]
          parts << "type=#{order_type}"
          parts << "price=$#{price}" if price&.positive?
          parts << "status=#{order_status}" if order_status
          parts << "traded=#{traded_qty}" if traded_qty&.positive?
          parts << "avg=$#{avg_traded_price}" if avg_traded_price&.positive?
          parts << "error=#{oms_error_description}" if oms_error_description
          parts.join(", ")
        end

        # @return [Boolean] True when the order can still be modified or cancelled.
        def pending?
          [DhanHQ::Constants::OrderStatus::PENDING,
           DhanHQ::Constants::OrderStatus::TRANSIT,
           DhanHQ::Constants::OrderStatus::PART_TRADED].include?(order_status)
        end

        # @return [Boolean] True when the order is fully executed.
        def traded?
          order_status == DhanHQ::Constants::OrderStatus::TRADED
        end

        # @return [Boolean] True when the order reached a terminal state.
        def closed?
          [DhanHQ::Constants::OrderStatus::TRADED,
           DhanHQ::Constants::OrderStatus::CANCELLED,
           DhanHQ::Constants::OrderStatus::REJECTED,
           DhanHQ::Constants::OrderStatus::EXPIRED].include?(order_status)
        end

        # @return [Boolean] True for a notional (dollar-value) order.
        def notional?
          order_type == DhanHQ::Constants::GlobalStocks::OrderType::AMOUNT
        end

        # @return [Boolean] True when the order is for a fractional share quantity.
        def fractional?
          return true if fractional_flag

          quantity.is_a?(Float) && (quantity % 1 != 0)
        end

        # Child legs of a Global Stocks super order, as {Order} instances.
        #
        # @return [Array<Order>]
        def child_legs
          Array(child_orders).map { |leg| self.class.new(leg, skip_validation: true) }
        end

        # Modifies this order in place and returns the refreshed record.
        #
        # @param params [Hash] Fields to change, in snake_case.
        # @return [Order, DhanHQ::ErrorObject]
        def modify(params = {})
          payload = { transaction_type: transaction_type, order_type: order_type, security_id: security_id }
                    .merge(params)
          response = self.class.resource.update(order_id, payload)
          return DhanHQ::ErrorObject.new(response) unless self.class.send(:successful?, response)

          self.class.find(order_id)
        end

        # Cancels this order.
        #
        # @return [Boolean] True when the API confirms cancellation.
        def cancel
          response = self.class.resource.cancel(order_id)
          status = response.is_a?(Hash) ? (response[:orderStatus] || response[:order_status]) : nil
          cancelled = status.to_s == DhanHQ::Constants::OrderStatus::CANCELLED
          DhanHQ.logger&.error("[#{self.class.name}] Cancel failed for order #{order_id}: #{response}") unless cancelled
          cancelled
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::Orders]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::Orders.new
          end

          # Retrieves the current trading day's Global Stocks order book.
          #
          # @return [Array<Order>]
          def all
            response = resource.all
            return [] unless response.is_a?(Array)

            response.map { |order| new(order, skip_validation: true) }
          end

          # Finds a single Global Stocks order by its Dhan order id.
          #
          # @param order_id [String]
          # @return [Order, nil]
          def find(order_id)
            response = resource.find(order_id)
            payload = response.is_a?(Array) ? response.first : response
            return nil unless payload.is_a?(Hash) && !payload.empty?

            new(payload, skip_validation: true)
          end

          # Places a new Global Stocks order.
          #
          # @param params [Hash] See {DhanHQ::Contracts::GlobalStocksPlaceOrderContract}.
          # @return [Order, DhanHQ::ErrorObject] The placed order, refetched so the
          #   caller gets the full record rather than just `{ orderId:, orderStatus: }`.
          def place(params)
            DhanHQ.logger&.info("[#{name}] Placing global order: #{params}")
            response = resource.create(params)
            return DhanHQ::ErrorObject.new(response) unless successful?(response)

            id = response[:orderId] || response[:order_id]
            DhanHQ.logger&.info("[#{name}] Global order placed successfully: #{id}")
            find(id) || new(response, skip_validation: true)
          end
          alias create place

          # Cancels a Global Stocks order by id.
          #
          # @param order_id [String]
          # @return [Boolean]
          def cancel(order_id)
            response = resource.cancel(order_id)
            status = response.is_a?(Hash) ? (response[:orderStatus] || response[:order_status]) : nil
            status.to_s == DhanHQ::Constants::OrderStatus::CANCELLED
          end

          private

          # An order write succeeded when the API echoed an order id back.
          def successful?(response)
            response.is_a?(Hash) && !(response[:orderId] || response[:order_id]).nil?
          end
        end
      end
    end
  end
end
