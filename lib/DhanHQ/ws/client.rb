# frozen_string_literal: true

require "concurrent"
require_relative "cmd_bus"
require_relative "sub_state"
require_relative "connection"
require_relative "decoder"
require_relative "segments"
require_relative "registry"

module DhanHQ
  module WS
    # Client responsible for managing the lifecycle of a streaming connection
    # to the DhanHQ market data WebSocket.
    #
    # The client encapsulates reconnection logic, subscription state tracking,
    # and event dispatching. It is typically used indirectly via
    # {DhanHQ::WS.connect}, but can also be instantiated directly for more
    # advanced flows.
    class Client
      # @param mode [Symbol] Feed mode (:ticker, :quote, :full).
      # @param url [String, nil] Optional custom WebSocket endpoint.
      def initialize(mode: :ticker, url: nil)
        @mode  = mode # :ticker, :quote, :full (adjust to your API)
        @bus   = CmdBus.new
        @state = SubState.new
        @callbacks = Concurrent::Map.new { |h, k| h[k] = [] }
        @started = Concurrent::AtomicBoolean.new(false)
        @last_message_at = Concurrent::AtomicReference.new(nil)
        @connected_at = Concurrent::AtomicReference.new(nil)
        @reconnects = Concurrent::AtomicFixnum.new(0)

        token = DhanHQ.configuration.resolved_access_token
        raise DhanHQ::AuthenticationError, "Missing access token" if token.nil? || token.empty?

        cid   = DhanHQ.configuration.client_id or raise "DhanHQ.client_id not set"
        ver   = (DhanHQ.configuration.respond_to?(:ws_version) && DhanHQ.configuration.ws_version) || 2
        base  = url || DhanHQ.configuration.ws_market_feed_url
        @url  = base.include?("?") ? base : "#{base}?version=#{ver}&token=#{token}&clientId=#{cid}&authType=2"
      end

      # Starts the WebSocket connection and event loop.
      #
      # @return [DhanHQ::WS::Client] self, to allow method chaining.
      def start
        return self if @started.true?

        @started.make_true
        @conn = Connection.new(url: @url, mode: @mode, bus: @bus, state: @state,
                               on_event: method(:handle_connection_event)) do |binary|
          tick = Decoder.decode(binary)
          emit(:tick, tick) if tick
        end
        Registry.register(self)
        install_at_exit_once!
        @conn.start
        self
      end

      # Gracefully stops the connection without sending a manual disconnect
      # frame.
      #
      # @return [DhanHQ::WS::Client] self.
      def stop
        return unless @started.true?

        @started.make_false
        @conn&.stop
        Registry.unregister(self)
        emit(:close, true)
        self
      end

      # Immediately disconnects from the feed by sending the disconnect frame
      # (RequestCode 12) before closing the socket.
      #
      # @return [DhanHQ::WS::Client] self.
      def disconnect!
        return self unless @started.true?

        @started.make_false
        @conn&.disconnect!
        Registry.unregister(self)
        emit(:close, true)
        self
      end

      # Indicates whether the underlying WebSocket connection is open.
      #
      # @return [Boolean]
      def connected?
        return false unless @started.true?

        @conn&.open? || false
      end

      # Timestamp of the most recently received frame.
      #
      # A feed can be "connected" and still be dead — the socket stays open while
      # the server has stopped publishing. Long-running daemons should watch this
      # rather than {#connected?} alone.
      #
      # @return [Time, nil] nil until the first frame arrives.
      def last_message_at
        @last_message_at.get
      end

      # Seconds since the last frame arrived.
      #
      # @return [Float, nil] nil until the first frame arrives.
      def seconds_since_last_message
        stamp = last_message_at
        return nil unless stamp

        Time.now - stamp
      end

      # Whether the feed looks alive: connected and delivering frames recently.
      #
      # @param stale_after [Numeric] Seconds of silence after which the feed is
      #   considered stale. The server pings roughly every 10 seconds, so the
      #   default allows several missed intervals.
      # @return [Boolean]
      def healthy?(stale_after: 45)
        return false unless connected?

        idle = seconds_since_last_message
        idle.nil? || idle <= stale_after
      end

      # Timestamp of the current connection's establishment.
      #
      # @return [Time, nil]
      def connected_at
        @connected_at.get
      end

      # Number of times the connection has been re-established since {#start}.
      #
      # @return [Integer]
      def reconnect_count
        @reconnects.value
      end

      # Instruments currently subscribed, as `"SEGMENT:SECURITY_ID"` strings.
      #
      # Survives reconnects: the connection replays this set on every new session.
      #
      # @return [Array<String>]
      def subscriptions
        @state.snapshot
      end

      # Point-in-time health snapshot, suitable for a monitoring endpoint or log line.
      #
      # @return [Hash]
      def health
        {
          mode: @mode,
          started: @started.true?,
          connected: connected?,
          healthy: healthy?,
          connected_at: connected_at,
          last_message_at: last_message_at,
          seconds_since_last_message: seconds_since_last_message,
          reconnect_count: reconnect_count,
          subscription_count: subscriptions.size
        }
      end

      # Subscribes to updates for a single instrument.
      #
      # @param segment [String, Symbol, Integer]
      # @param security_id [String, Integer]
      # @return [DhanHQ::WS::Client] self.
      def subscribe_one(segment:, security_id:)
        norm = Segments.normalize_instrument(ExchangeSegment: segment, SecurityId: security_id)
        DhanHQ.logger&.info("[DhanHQ::WS] subscribe_one (normalized) -> #{norm}")
        @bus.sub([prune(norm)])
        self
      end

      # Subscribes to updates for a list of instruments.
      #
      # @param list [Array<Hash>] Array containing instrument hashes with
      #   +:ExchangeSegment+ and +:SecurityId+ keys.
      # @return [DhanHQ::WS::Client] self.
      def subscribe_many(list)
        norms = Segments.normalize_instruments(list).map { |i| prune(i) }
        DhanHQ.logger&.info("[DhanHQ::WS] subscribe_many (normalized) -> #{norms}")
        @bus.sub(norms)
        self
      end

      # Removes the subscription for a single instrument.
      #
      # @param segment [String, Symbol, Integer]
      # @param security_id [String, Integer]
      # @return [DhanHQ::WS::Client] self.
      def unsubscribe_one(segment:, security_id:)
        norm = Segments.normalize_instrument(ExchangeSegment: segment, SecurityId: security_id)
        DhanHQ.logger&.info("[DhanHQ::WS] unsubscribe_one (normalized) -> #{norm}")
        @bus.unsub([prune(norm)])
        self
      end

      # Removes the subscriptions for a list of instruments.
      #
      # @param list [Array<Hash>] Instrument definitions to unsubscribe.
      # @return [DhanHQ::WS::Client] self.
      def unsubscribe_many(list)
        norms = Segments.normalize_instruments(list).map { |i| prune(i) }
        DhanHQ.logger&.info("[DhanHQ::WS] unsubscribe_many (normalized) -> #{norms}")
        @bus.unsub(norms)
        self
      end

      # Installs a single +at_exit+ hook to close open WebSocket clients.
      #
      # @return [void]
      def self.install_at_exit_hook!
        return if defined?(@_at_exit_installed) && @_at_exit_installed

        @_at_exit_installed = true
        at_exit do
          DhanHQ.logger&.info("[DhanHQ::WS] at_exit: disconnecting all local clients")
          Registry.stop_all
        rescue StandardError => e
          DhanHQ.logger&.debug("[DhanHQ::WS] at_exit error #{e.class}: #{e.message}")
        end
      end

      # Registers a callback for a given event.
      #
      # Supported events:
      #
      # - +:tick+ — a decoded market data packet.
      # - +:open+ — the socket connected. Payload: `{ resubscribed: [...] }`.
      # - +:reconnect+ — the socket re-connected after a drop. Payload:
      #   `{ attempt: Integer, resubscribed: [...] }`. Subscriptions are replayed
      #   automatically before this fires; use it to re-seed derived state such as
      #   candle builders or to alert.
      # - +:close+ — the socket closed. Payload:
      #   `{ code:, reason:, reconnecting: Boolean }`.
      # - +:error+ — a socket-level error. Payload: the error message.
      #
      # @param event [Symbol] Event name.
      # @yieldparam payload [Object] Event payload.
      # @return [DhanHQ::WS::Client] self.
      #
      # @example React to a reconnect
      #   client.on(:reconnect) do |info|
      #     logger.warn "feed reconnected (attempt #{info[:attempt]}), " \
      #                 "#{info[:resubscribed].size} instruments restored"
      #   end
      def on(event, &blk)
        @callbacks[event] << blk
        self
      end

      private

      # Bridges connection-level lifecycle events onto the client's callback bus and
      # updates the health counters. +:message+ is internal bookkeeping only — the
      # decoded payload reaches users as +:tick+.
      def handle_connection_event(event, payload)
        case event
        when :message
          @last_message_at.set(Time.now)
          return
        when :open
          @connected_at.set(Time.now)
        when :reconnect
          @reconnects.increment
        when :close
          @connected_at.set(nil)
        end

        emit(event, payload)
      end

      def prune(hash) = { ExchangeSegment: hash[:ExchangeSegment], SecurityId: hash[:SecurityId] }

      def emit(event, payload)
        # Create a frozen snapshot of callbacks to avoid modification during iteration
        callbacks_snapshot = begin
          @callbacks[event].dup.freeze
        rescue StandardError
          [].freeze
        end

        callbacks_snapshot.each { |cb| cb.call(payload) }
      rescue StandardError => e
        DhanHQ.logger&.error("[DhanHQ::WS::Client] Error in event handler for #{event}: #{e.class} #{e.message}")
      end

      def install_at_exit_once!
        return if defined?(@at_exit_installed) && @at_exit_installed

        @at_exit_installed = true
        at_exit { Registry.stop_all }
      end
    end
  end
end
