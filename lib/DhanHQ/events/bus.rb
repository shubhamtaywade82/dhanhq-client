# frozen_string_literal: true

module DhanHQ
  # Event-driven architecture for the trading system.
  #
  # Provides pub/sub event bus, typed events, and async helpers.
  #
  # @example Subscribe to events
  #   DhanHQ::Events.on(:order_filled) do |event|
  #     puts "Order filled: #{event.order_id}"
  #   end
  #
  # @example Emit events
  #   DhanHQ::Events.emit(:order_filled, order_id: "123", filled_quantity: 10)
  #
  module Events
    # Simple pub/sub event bus.
    #
    # Supports subscribing to specific event types or all events.
    class Bus
      def initialize
        @subscribers = Hash.new { |h, k| h[k] = [] }
        @global_subscribers = []
      end

      # Subscribe to an event type.
      #
      # @param event_type [Symbol, Class] Event type to subscribe to
      # @param block [Proc] Handler block
      # @return [Integer] Subscription ID for unsubscribing
      def on(event_type, &block)
        @subscribers[event_type] << block
        @subscribers[event_type].length - 1
      end

      # Subscribe to all events.
      #
      # @param block [Proc] Handler block
      # @return [Integer] Subscription ID
      def subscribe_all(&block)
        @global_subscribers << block
        @global_subscribers.length - 1
      end

      # Unsubscribe from an event type.
      #
      # @param event_type [Symbol, Class] Event type
      # @param subscription_id [Integer] Subscription ID from on()
      # @return [Boolean] True if unsubscribed
      # rubocop:disable Naming/PredicateMethod
      def off(event_type, subscription_id)
        return false unless @subscribers[event_type]

        @subscribers[event_type].delete_at(subscription_id)
        true
      end

      # Unsubscribe from all events.
      #
      # @param subscription_id [Integer] Subscription ID
      # @return [Boolean] True if unsubscribed
      def unsubscribe_all(subscription_id)
        @global_subscribers.delete_at(subscription_id)
        true
      end
      # rubocop:enable Naming/PredicateMethod

      # Emit an event to all subscribers.
      #
      # @param event_type [Symbol, Class] Event type
      # @param data [Hash] Event data
      # @return [void]
      def emit(event_type, data = {})
        event = build_event(event_type, data)

        # Notify type-specific subscribers
        @subscribers[event_type]&.each do |handler|
          handler.call(event)
        rescue StandardError => e
          DhanHQ.logger&.error("[Events] Error in handler for #{event_type}: #{e.message}")
        end

        # Notify global subscribers
        @global_subscribers.each do |handler|
          handler.call(event_type, event)
        rescue StandardError => e
          DhanHQ.logger&.error("[Events] Error in global handler: #{e.message}")
        end
      end

      # Get count of subscribers for an event type.
      #
      # @param event_type [Symbol] Event type
      # @return [Integer]
      def subscriber_count(event_type)
        @subscribers[event_type]&.length || 0
      end

      # Clear all subscribers.
      def clear
        @subscribers.clear
        @global_subscribers.clear
      end

      private

      def build_event(event_type, data)
        case event_type
        when :order_placed then OrderPlaced.new(data)
        when :order_filled then OrderFilled.new(data)
        when :order_cancelled then OrderCancelled.new(data)
        when :order_rejected then OrderRejected.new(data)
        when :sl_hit then SLHit.new(data)
        when :tp_hit then TPHit.new(data)
        when :tick_updated then TickUpdated.new(data)
        when :position_opened then PositionOpened.new(data)
        when :position_closed then PositionClosed.new(data)
        when :strategy_signal then StrategySignal.new(data)
        else
          Base.new(data.merge(event_type: event_type))
        end
      end
    end

    # Default bus instance
    @bus = Bus.new

    class << self
      # Get the default event bus.
      attr_reader :bus

      # Subscribe to an event type (delegates to bus).
      def on(event_type, &)
        bus.on(event_type, &)
      end

      # Subscribe to all events (delegates to bus).
      def subscribe_all(&)
        bus.subscribe_all(&)
      end

      # Emit an event (delegates to bus).
      def emit(event_type, data = {})
        bus.emit(event_type, data)
      end

      # Unsubscribe from an event type (delegates to bus).
      def off(event_type, subscription_id)
        bus.off(event_type, subscription_id)
      end

      # Clear all subscribers (delegates to bus).
      def clear
        bus.clear
      end
    end
  end
end
