# frozen_string_literal: true

require_relative "events/base"
require_relative "events/bus"

module DhanHQ
  # Event-driven architecture for the trading system.
  #
  # Provides typed events, pub/sub event bus, and async helpers
  # for building reactive trading applications.
  #
  # @example Subscribe to order events
  #   DhanHQ::Events.on(:order_filled) do |event|
  #     puts "Order filled: #{event.order_id}"
  #     puts "Filled quantity: #{event.filled_quantity}"
  #   end
  #
  # @example Emit events
  #   DhanHQ::Events.emit(:order_filled, order_id: "123", filled_quantity: 10)
  #
  # @example Subscribe to all events
  #   DhanHQ::Events.subscribe_all do |event_type, event|
  #     puts "Event: #{event_type} - #{event}"
  #   end
  #
  # Available event types:
  # - :order_placed - Order placed successfully
  # - :order_filled - Order fully or partially filled
  # - :order_cancelled - Order cancelled
  # - :order_rejected - Order rejected by exchange
  # - :sl_hit - Stop loss triggered
  # - :tp_hit - Take profit triggered
  # - :tick_updated - New market tick received
  # - :position_opened - New position opened
  # - :position_closed - Position closed
  # - :strategy_signal - Strategy generated a signal
  #
  module Events
  end
end
