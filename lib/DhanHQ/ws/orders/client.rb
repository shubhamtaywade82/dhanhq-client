# frozen_string_literal: true

require "concurrent"
require_relative "connection"

module DhanHQ
  module WS
    module Orders
      ##
      # Enhanced WebSocket client for real-time order updates
      # Provides comprehensive order state tracking and event handling
      # rubocop:disable Metrics/ClassLength
      class Client
        # Maximum number of orders to keep in tracker (default: 10,000)
        MAX_TRACKED_ORDERS = ENV.fetch("DHAN_WS_MAX_TRACKED_ORDERS", 10_000).to_i
        
        # Maximum age of orders in tracker in seconds (default: 7 days)
        MAX_ORDER_AGE = ENV.fetch("DHAN_WS_MAX_ORDER_AGE", 604_800).to_i

        def initialize(url: nil, **options)
          @callbacks = Concurrent::Map.new { |h, k| h[k] = [] }
          @started = Concurrent::AtomicBoolean.new(false)
          @order_tracker = Concurrent::Map.new
          @order_timestamps = Concurrent::Map.new
          @cleanup_mutex = Mutex.new
          @cleanup_thread = nil
          cfg = DhanHQ.configuration
          @url = url || cfg.ws_order_url
          @connection_options = options
        end

        ##
        # Start the WebSocket connection and begin receiving order updates
        # @return [Client] self for method chaining
        def start
          return self if @started.true?

          @started.make_true
          @conn = Connection.new(url: @url, **@connection_options)
          @conn.on(:open) { emit(:open, true) }
          @conn.on(:close) { |payload| emit(:close, payload) }
          @conn.on(:error) { |error| emit(:error, error) }
          @conn.on(:message) { |msg| handle_message(msg) }
          @conn.start
          start_cleanup_thread
          DhanHQ::WS::Registry.register(self) if defined?(DhanHQ::WS::Registry)
          self
        end

        ##
        # Stop the WebSocket connection
        # @return [void]
        def stop
          return unless @started.true?

          @started.make_false
          stop_cleanup_thread
          @conn&.stop
          emit(:close, true)
          DhanHQ::WS::Registry.unregister(self) if defined?(DhanHQ::WS::Registry)
        end

        ##
        # Force disconnect the WebSocket
        # @return [void]
        def disconnect!
          @conn&.disconnect!
        end

        ##
        # Register event handlers
        # @param event [Symbol] Event type (:update, :raw, :status_change, :execution, :error)
        # @param block [Proc] Event handler
        # @return [Client] self for method chaining
        def on(event, &block)
          @callbacks[event] << block
          self
        end

        ##
        # Get current order state for a specific order
        # @param order_no [String] Order number
        # @return [OrderUpdate, nil] Latest order update or nil if not found
        def order_state(order_no)
          @order_tracker[order_no]
        end

        ##
        # Get all tracked orders
        # @return [Hash] Hash of order_no => OrderUpdate
        def all_orders
          @order_tracker.dup
        end

        ##
        # Get orders by status
        # @param status [String] Order status (TRANSIT, PENDING, REJECTED, etc.)
        # @return [Array<OrderUpdate>] Orders with the specified status
        def orders_by_status(status)
          @order_tracker.values.select { |order| order.status == status }
        end

        ##
        # Get orders by symbol
        # @param symbol [String] Trading symbol
        # @return [Array<OrderUpdate>] Orders for the specified symbol
        def orders_by_symbol(symbol)
          @order_tracker.values.select { |order| order.symbol == symbol }
        end

        ##
        # Get partially executed orders
        # @return [Array<OrderUpdate>] Orders that are partially executed
        def partially_executed_orders
          @order_tracker.values.select(&:partially_executed?)
        end

        ##
        # Get fully executed orders
        # @return [Array<OrderUpdate>] Orders that are fully executed
        def fully_executed_orders
          @order_tracker.values.select(&:fully_executed?)
        end

        ##
        # Get pending orders (not executed)
        # @return [Array<OrderUpdate>] Orders that are not executed
        def pending_orders
          @order_tracker.values.select(&:not_executed?)
        end

        ##
        # Check if connection is active
        # @return [Boolean] true if connected
        def connected?
          @conn&.open? || false
        end

        private

        ##
        # Handle incoming WebSocket messages
        # @param msg [Hash] Raw WebSocket message
        def handle_message(msg)
          # Emit raw message for debugging
          emit(:raw, msg)

          # Handle order updates
          if msg&.dig(:Type) == "order_alert"
            order_update = DhanHQ::Models::OrderUpdate.from_websocket_message(msg)
            handle_order_update(order_update) if order_update
          end

          # Handle other message types
          emit(:message, msg)
        end

        ##
        # Handle order update and track state changes
        # @param order_update [OrderUpdate] Parsed order update
        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        def handle_order_update(order_update)
          order_no = order_update.order_no
          previous_state = @order_tracker[order_no]

          # Update order tracker with timestamp
          @order_tracker[order_no] = order_update
          @order_timestamps[order_no] = Time.now

          # Cleanup if tracker exceeds max size
          cleanup_old_orders if @order_tracker.size > MAX_TRACKED_ORDERS

          # Emit update event
          emit(:update, order_update)

          # Check for status changes
          if previous_state && previous_state.status != order_update.status
            emit(:status_change, {
                   order_update: order_update,
                   previous_status: previous_state.status,
                   new_status: order_update.status
                 })
          end

          # Check for execution updates
          if previous_state && previous_state.traded_qty != order_update.traded_qty
            emit(:execution, {
                   order_update: order_update,
                   previous_traded_qty: previous_state.traded_qty,
                   new_traded_qty: order_update.traded_qty,
                   execution_percentage: order_update.execution_percentage
                 })
          end

          # Emit specific status events
          emit_status_specific_events(order_update, previous_state)
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        ##
        # Emit status-specific events
        #
        # @param order_update [OrderUpdate] Current order update
        # @param _previous_state [OrderUpdate, nil] Previous order state (unused parameter)
        # rubocop:disable Metrics/MethodLength
        def emit_status_specific_events(order_update, _previous_state)
          case order_update.status
          when "TRANSIT"
            emit(:order_transit, order_update)
          when "PENDING"
            emit(:order_pending, order_update)
          when "REJECTED"
            emit(:order_rejected, order_update)
          when "CANCELLED"
            emit(:order_cancelled, order_update)
          when "TRADED"
            emit(:order_traded, order_update)
          when "EXPIRED"
            emit(:order_expired, order_update)
          end
        end
        # rubocop:enable Metrics/MethodLength

        ##
        # Emit events to registered callbacks
        # @param event [Symbol] Event type
        # @param payload [Object] Event payload
        def emit(event, payload)
          # Create a snapshot of callbacks to avoid modification during iteration
          callbacks_snapshot = begin
            @callbacks[event].dup.freeze
          rescue StandardError
            [].freeze
          end
          
          callbacks_snapshot.each { |cb| cb.call(payload) }
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::Orders] Error in event handler: #{e.class} #{e.message}")
        end

        ##
        # Start cleanup thread to periodically remove old orders
        def start_cleanup_thread
          return if @cleanup_thread&.alive?

          @cleanup_thread = Thread.new do
            loop do
              break unless @started.true?
              sleep(3600) # Run cleanup every hour
              break unless @started.true?
              cleanup_old_orders
            end
          end
        end

        ##
        # Stop cleanup thread
        def stop_cleanup_thread
          return unless @cleanup_thread&.alive?

          @cleanup_thread.wakeup
          @cleanup_thread.join(5) # Wait up to 5 seconds
          @cleanup_thread = nil
        end

        ##
        # Clean up old orders from tracker
        def cleanup_old_orders
          @cleanup_mutex.synchronize do
            now = Time.now
            orders_to_remove = []

            # Find orders to remove (too old or if tracker is too large)
            @order_timestamps.each do |order_no, timestamp|
              age = now - timestamp
              if age > MAX_ORDER_AGE || (@order_tracker.size > MAX_TRACKED_ORDERS && orders_to_remove.size < @order_tracker.size - MAX_TRACKED_ORDERS)
                orders_to_remove << order_no
              end
            end

            # Remove old orders
            orders_to_remove.each do |order_no|
              @order_tracker.delete(order_no)
              @order_timestamps.delete(order_no)
            end

            DhanHQ.logger&.debug("[DhanHQ::WS::Orders] Cleaned up #{orders_to_remove.size} old orders") if orders_to_remove.any?
          end
        end
      end
      # rubocop:enable Metrics/ClassLength
    end
  end
end
