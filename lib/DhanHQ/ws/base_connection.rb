# frozen_string_literal: true

require "eventmachine"
require "faye/websocket"
require "json"
require "concurrent"
require "uri"

module DhanHQ
  module WS
    ##
    # Base WebSocket connection class providing common functionality
    # for all DhanHQ WebSocket connections (Orders, Market Feed, Market Depth)
    class BaseConnection
      COOL_OFF_429 = 60  # seconds to cool off on 429
      MAX_BACKOFF  = 90  # cap exponential backoff

      attr_reader :stopping, :url, :callbacks, :started

      ##
      # Initialize base connection
      # @param url [String] WebSocket endpoint URL
      # @param options [Hash] Connection options
      # @option options [Integer] :max_backoff Maximum backoff time (default: 90)
      # @option options [Integer] :cool_off_429 Cool off time for 429 errors (default: 60)
      def initialize(url:, **options)
        @url = url
        @callbacks = Concurrent::Map.new { |h, k| h[k] = [] }
        @started = Concurrent::AtomicBoolean.new(false)
        @stop = false
        @stopping = false
        @ws = nil
        @timer = nil
        @cooloff_until = nil
        @thr = nil
        @max_backoff = options[:max_backoff] || MAX_BACKOFF
        @cool_off_429 = options[:cool_off_429] || COOL_OFF_429
      end

      ##
      # Start the WebSocket connection
      # @return [BaseConnection] self for method chaining
      def start
        return self if @started.true?

        @started.make_true
        @thr = Thread.new { loop_run }
        self
      end

      ##
      # Stop the WebSocket connection gracefully
      # @return [BaseConnection] self for method chaining
      def stop
        return self unless @started.true?

        @started.make_false
        @stop = true
        @stopping = true
        @ws&.close
        self
      end

      ##
      # Force disconnect the WebSocket
      # @return [BaseConnection] self for method chaining
      def disconnect!
        @stop = true
        @stopping = true
        @ws&.close
        self
      end

      ##
      # Check if connection is open
      # @return [Boolean] true if connected
      def open?
        @ws && @ws.instance_variable_get(:@driver)&.ready_state == 1
      rescue StandardError
        false
      end

      ##
      # Check if connection is connected (alias for open?)
      # @return [Boolean] true if connected
      def connected?
        open?
      end

      ##
      # Register event handler
      # @param event [Symbol] Event type
      # @param block [Proc] Event handler
      # @return [BaseConnection] self for method chaining
      def on(event, &block)
        @callbacks[event] << block
        self
      end

      ##
      # Emit event to registered callbacks
      # @param event [Symbol] Event type
      # @param payload [Object] Event payload
      def emit(event, payload = nil)
        list = @callbacks[event] || []
        list.each { |cb| cb.call(payload) }
      rescue StandardError => e
        DhanHQ.logger&.error("[DhanHQ::WS::BaseConnection] Error in event handler: #{e.class} #{e.message}")
      end

      ##
      # Send message over WebSocket
      # @param message [String, Hash] Message to send
      def send_message(message)
        return unless @ws && open?

        data = message.is_a?(Hash) ? message.to_json : message
        @ws.send(data)
      rescue StandardError => e
        DhanHQ.logger&.error("[DhanHQ::WS::BaseConnection] Error sending message: #{e.class} #{e.message}")
      end

      private

      ##
      # Main connection loop with reconnection logic
      def loop_run
        backoff = 2.0
        until @stop
          failed = false
          got_429 = false

          # Respect any active cool-off window
          sleep (@cooloff_until - Time.now).ceil if @cooloff_until && Time.now < @cooloff_until

          begin
            failed, got_429 = run_session
          rescue StandardError => e
            DhanHQ.logger&.error("[DhanHQ::WS::BaseConnection] Connection crashed: #{e.class} #{e.message}")
            failed = true
          ensure
            break if @stop

            if got_429
              @cooloff_until = Time.now + @cool_off_429
              DhanHQ.logger&.warn("[DhanHQ::WS::BaseConnection] Cooling off #{@cool_off_429}s due to 429")
            end

            if failed
              sleep_time = [backoff, @max_backoff].min
              jitter = rand(0.2 * sleep_time)
              DhanHQ.logger&.warn("[DhanHQ::WS::BaseConnection] Reconnecting in #{(sleep_time + jitter).round(1)}s")
              sleep(sleep_time + jitter)
              backoff *= 2.0
            else
              backoff = 2.0
            end
          end
        end
      end

      ##
      # Run a single WebSocket session
      # Must be implemented by subclasses
      # @return [Array<Boolean>] [failed, got_429]
      def run_session
        raise NotImplementedError, "Subclasses must implement run_session"
      end

      ##
      # Get default headers for WebSocket connection
      # @return [Hash] Default headers
      def default_headers
        {
          "User-Agent" => "DhanHQ-Ruby-Client/#{DhanHQ::VERSION}",
          "Origin" => "https://dhanhq.co"
        }
      end

      ##
      # Sanitize URL for logging by removing sensitive parameters
      # @param url [String] Original URL
      # @return [String] Sanitized URL safe for logging
      def sanitize_url(url)
        return url if url.nil? || url.empty?

        begin
          uri = URI.parse(url)
          # Remove sensitive query parameters
          if uri.query
            params = URI.decode_www_form(uri.query).reject do |key, _|
              %w[token clientId client_id access_token].include?(key.downcase)
            end
            uri.query = URI.encode_www_form(params) unless params.empty?
          end
          uri.to_s
        rescue StandardError
          # If URL parsing fails, return a generic message
          "wss://[sanitized-url]"
        end
      end

      ##
      # Handle WebSocket open event
      def handle_open
        DhanHQ.logger&.info("[DhanHQ::WS::BaseConnection] Connected to #{sanitize_url(@url)}")
        emit(:open)
        authenticate if respond_to?(:authenticate, true)
      end

      ##
      # Handle WebSocket message event
      # @param ev [Event] WebSocket message event
      def handle_message(ev)
        emit(:raw, ev.data)
        process_message(ev.data) if respond_to?(:process_message, true)
      end

      ##
      # Handle WebSocket close event
      # @param ev [Event] WebSocket close event
      def handle_close(ev)
        @timer&.cancel
        @timer = nil
        msg = "[DhanHQ::WS::BaseConnection] Connection closed: #{ev.code} #{ev.reason}"
        DhanHQ.logger&.warn(msg)

        emit(:close, { code: ev.code, reason: ev.reason })

        if @stopping
          [false, false]
        else
          failed = (ev.code != 1000)
          got_429 = ev.reason.to_s.include?("429")
          [failed, got_429]
        end
      end

      ##
      # Handle WebSocket error event
      # @param ev [Event] WebSocket error event
      def handle_error(ev)
        DhanHQ.logger&.error("[DhanHQ::WS::BaseConnection] WebSocket error: #{ev.message}")
        emit(:error, ev.message)
        [true, false]
      end
    end
  end
end
