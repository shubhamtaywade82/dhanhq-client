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

        token = DhanHQ.configuration.resolved_access_token
        raise DhanHQ::AuthenticationError, "Missing access token" if token.nil? || token.empty?
        cid   = DhanHQ.configuration.client_id or raise "DhanHQ.client_id not set"
        ver   = (DhanHQ.configuration.respond_to?(:ws_version) && DhanHQ.configuration.ws_version) || 2
        @url  = url || "wss://api-feed.dhan.co?version=#{ver}&token=#{token}&clientId=#{cid}&authType=2"
      end

      # Starts the WebSocket connection and event loop.
      #
      # @return [DhanHQ::WS::Client] self, to allow method chaining.
      def start
        return self if @started.true?

        @started.make_true
        @conn = Connection.new(url: @url, mode: @mode, bus: @bus, state: @state) do |binary|
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
      # @param event [Symbol] Event name (:tick, :open, :close, :error).
      # @yieldparam payload [Object] Event payload.
      # @return [DhanHQ::WS::Client] self.
      def on(event, &blk)
        @callbacks[event] << blk
        self
      end

      private

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
