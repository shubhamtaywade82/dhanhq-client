# frozen_string_literal: true

module DhanHQ
  # Event types for the trading system.
  #
  # Provides typed event classes for order lifecycle, market data,
  # position updates, and strategy signals.
  #
  # @example Subscribe to order events
  #   DhanHQ::Events.on(:order_filled) do |event|
  #     puts "Order filled: #{event.order_id}"
  #   end
  #
  module Events
    # Base event class with common attributes.
    class Base
      attr_reader :timestamp, :data

      def initialize(data = {})
        @timestamp = Time.now
        @data = data
      end

      def to_h
        {
          event_type: self.class.name.split("::").last.downcase.to_sym,
          timestamp: timestamp,
          data: data
        }
      end

      def to_prompt
        "#{self.class.name.split("::").last}: #{data.inspect}"
      end
    end

    # Order placed event.
    class OrderPlaced < Base
      def order_id
        data[:order_id]
      end

      def to_s
        "OrderPlaced(#{order_id})"
      end
    end

    # Order filled event.
    class OrderFilled < Base
      def order_id
        data[:order_id]
      end

      def filled_quantity
        data[:filled_quantity]
      end

      def filled_price
        data[:filled_price]
      end

      def to_s
        "OrderFilled(#{order_id}, #{filled_quantity}@#{filled_price})"
      end
    end

    # Order cancelled event.
    class OrderCancelled < Base
      def order_id
        data[:order_id]
      end

      def reason
        data[:reason]
      end

      def to_s
        "OrderCancelled(#{order_id}, reason=#{reason})"
      end
    end

    # Order rejected event.
    class OrderRejected < Base
      def order_id
        data[:order_id]
      end

      def error_code
        data[:error_code]
      end

      def error_message
        data[:error_message]
      end

      def to_s
        "OrderRejected(#{order_id}, #{error_code}: #{error_message})"
      end
    end

    # Stop loss hit event.
    class SLHit < Base
      def order_id
        data[:order_id]
      end

      def trigger_price
        data[:trigger_price]
      end

      def to_s
        "SLHit(#{order_id}, trigger=#{trigger_price})"
      end
    end

    # Take profit hit event.
    class TPHit < Base
      def order_id
        data[:order_id]
      end

      def target_price
        data[:target_price]
      end

      def to_s
        "TPHit(#{order_id}, target=#{target_price})"
      end
    end

    # Market data tick event.
    class TickUpdated < Base
      def security_id
        data[:security_id]
      end

      def ltp
        data[:ltp]
      end

      def volume
        data[:volume]
      end

      def to_s
        "TickUpdated(#{security_id}, ltp=#{ltp})"
      end
    end

    # Position opened event.
    class PositionOpened < Base
      def security_id
        data[:security_id]
      end

      def quantity
        data[:quantity]
      end

      def side
        data[:side]
      end

      def to_s
        "PositionOpened(#{security_id}, #{side} #{quantity})"
      end
    end

    # Position closed event.
    class PositionClosed < Base
      def security_id
        data[:security_id]
      end

      def profit_loss
        data[:profit_loss]
      end

      def to_s
        "PositionClosed(#{security_id}, pnl=#{profit_loss})"
      end
    end

    # Strategy signal event.
    class StrategySignal < Base
      def strategy_name
        data[:strategy_name]
      end

      def signal_type
        data[:signal_type]
      end

      def strength
        data[:strength]
      end

      def to_s
        "StrategySignal(#{strategy_name}, #{signal_type}, strength=#{strength})"
      end
    end
  end
end
