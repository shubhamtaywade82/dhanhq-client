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
    class Client
      def initialize(mode: :ticker, url: nil)
        @mode  = mode # :ticker, :quote, :full (adjust to your API)
        @bus   = CmdBus.new
        @state = SubState.new
        @callbacks = Concurrent::Map.new { |h, k| h[k] = [] }
        @started = Concurrent::AtomicBoolean.new(false)

        token = DhanHQ.configuration.access_token or raise "DhanHQ.access_token not set"
        cid   = DhanHQ.configuration.client_id or raise "DhanHQ.client_id not set"
        ver   = (DhanHQ.configuration.respond_to?(:ws_version) && DhanHQ.configuration.ws_version) || 2
        @url  = url || "wss://api-feed.dhan.co?version=#{ver}&token=#{token}&clientId=#{cid}&authType=2"
      end

      # lifecycle
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

      def stop
        return unless @started.true?

        @started.make_false
        @conn&.stop
        Registry.unregister(self)
        emit(:close, true)
        self
      end

      # Manual “disconnect feed now” (sends RequestCode 12)
      def disconnect!
        return self unless @started.true?

        @started.make_false
        @conn&.disconnect!
        Registry.unregister(self)
        emit(:close, true)
        self
      end

      def connected?
        return false unless @started.true?

        @conn&.open? || false
      end

      # subscriptions (accept either one or an array)
      def subscribe_one(segment:, security_id:)
        norm = Segments.normalize_instrument(ExchangeSegment: segment, SecurityId: security_id)
        DhanHQ.logger&.info("[DhanHQ::WS] subscribe_one (normalized) -> #{norm}")
        @bus.sub([prune(norm)])
        self
      end

      # [{ExchangeSegment:, SecurityId:}, ...]
      def subscribe_many(list)
        norms = Segments.normalize_instruments(list).map { |i| prune(i) }
        DhanHQ.logger&.info("[DhanHQ::WS] subscribe_many (normalized) -> #{norms}")
        @bus.sub(norms)
        self
      end

      def unsubscribe_one(segment:, security_id:)
        norm = Segments.normalize_instrument(ExchangeSegment: segment, SecurityId: security_id)
        DhanHQ.logger&.info("[DhanHQ::WS] unsubscribe_one (normalized) -> #{norm}")
        @bus.unsub([prune(norm)])
        self
      end

      def unsubscribe_many(list)
        norms = Segments.normalize_instruments(list).map { |i| prune(i) }
        DhanHQ.logger&.info("[DhanHQ::WS] unsubscribe_many (normalized) -> #{norms}")
        @bus.unsub(norms)
        self
      end

      # ensure we only install one at_exit per process
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

      # events: :tick, :open, :close, :error
      def on(event, &blk)
        @callbacks[event] << blk
        self
      end

      private

      def prune(h) = { ExchangeSegment: h[:ExchangeSegment], SecurityId: h[:SecurityId] }

      def emit(event, payload)
        begin
          @callbacks[event].dup
        rescue StandardError
          []
        end.each { |cb| cb.call(payload) }
      end

      def install_at_exit_once!
        return if defined?(@at_exit_installed) && @at_exit_installed

        @at_exit_installed = true
        at_exit { Registry.stop_all }
      end
    end
  end
end
