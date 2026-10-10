# frozen_string_literal: true

require "yaml"

module DhanHQ
  module WS
    # Loads the WebSocket binary-protocol manifest
    # (contracts/dhanhq/ws_protocol.yml) — the machine-readable contract for
    # the feed's byte-level wire format, request codes and segment enum.
    #
    # Runtime code derives its wire knowledge from here instead of
    # hand-transcribing it: the segment enum, the subscribe/unsubscribe
    # request codes (the F1/F2 bug class) and the FMD frame geometry all come
    # from the manifest, and the protocol spec packs binary fixtures FROM the
    # manifest to keep the decoders and the contract locked together.
    class Protocol
      MANIFEST_PATH = File.expand_path("../../../contracts/dhanhq/ws_protocol.yml", __dir__)

      class << self
        # @return [Hash] The frozen manifest
        def manifest
          @manifest ||= YAML.safe_load(File.read(MANIFEST_PATH), aliases: true).freeze
        rescue Psych::SyntaxError => e
          raise "ws_protocol.yml is not valid YAML: #{e.message}"
        end

        # -- exchange segments ------------------------------------------------

        # @return [Hash{String => Integer}] e.g. {"NSE_EQ" => 1}
        def exchange_segments
          @exchange_segments ||= manifest.fetch("exchange_segments").freeze
        end

        # @return [Hash{Integer => String}]
        def exchange_segments_by_code
          @exchange_segments_by_code ||= exchange_segments.invert.freeze
        end

        # -- request codes ----------------------------------------------------

        # @param family [Symbol] :index, :ticker, :quote, :depth, :full, :market_depth
        # @param direction [Symbol] :subscribe or :unsubscribe
        # @return [Integer]
        def request_code(family, direction)
          manifest.fetch("request_codes").fetch(direction.to_s).fetch(family.to_s).to_i
        end

        # @return [Integer] The whole-connection disconnect RequestCode (12).
        #   This is NOT an unsubscribe code — it tears the socket down.
        def disconnect_request_code
          @disconnect_request_code ||= manifest.fetch("request_codes").fetch("disconnect").to_i
        end

        # -- response codes & packets ------------------------------------------

        # @param name [Symbol] :index, :ticker, :depth, :quote, :oi,
        #   :prev_close, :market_status, :full, :disconnect
        # @return [Integer]
        def response_code(name)
          manifest.fetch("response_codes").fetch(name.to_s).to_i
        end

        # @param name [Symbol] Packet name
        # @return [Hash] Packet layout (code, size, fields, arrays)
        def packet(name)
          manifest.fetch("packets").fetch(name.to_s)
        end

        # @return [Hash] The 8-byte response-header layout
        def response_header
          @response_header ||= manifest.fetch("response_header").freeze
        end

        # -- full market depth --------------------------------------------------

        def full_market_depth
          @full_market_depth ||= manifest.fetch("full_market_depth").freeze
        end

        # -- disconnect codes ----------------------------------------------------

        # @return [Hash{String => String}] e.g. {"805" => "Connection limit exceeded"}
        def disconnect_codes
          @disconnect_codes ||= manifest.fetch("disconnect_codes").transform_keys(&:to_s).freeze
        end

        # @param code [Integer]
        # @return [String, nil] Human-readable reason
        def disconnect_reason(code)
          disconnect_codes[code.to_s]
        end

        # -- limits / heartbeat ---------------------------------------------------

        def connection_limits
          @connection_limits ||= manifest.fetch("connection").freeze
        end

        # Clears memoized state (spec reloads).
        def reset!
          @manifest = nil
          @exchange_segments = nil
          @exchange_segments_by_code = nil
          @disconnect_request_code = nil
          @response_header = nil
          @full_market_depth = nil
          @disconnect_codes = nil
          @connection_limits = nil
        end
      end
    end
  end
end
