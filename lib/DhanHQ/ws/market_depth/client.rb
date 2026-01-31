# frozen_string_literal: true

require "concurrent"
require_relative "../base_connection"
require_relative "decoder"
require_relative "../../models/instrument"
require_relative "../../constants"

module DhanHQ
  module WS
    module MarketDepth
      ##
      # WebSocket client for Full Market Depth data
      # Provides real-time market depth (bid/ask levels) for specified symbols
      class Client < BaseConnection
        SUBSCRIBE_REQUEST_CODE    = 23
        UNSUBSCRIBE_REQUEST_CODE  = 12

        ##
        # Initialize Market Depth WebSocket client
        # @param symbols [Array<String, Hash>] List of symbols (or metadata hashes) to subscribe to
        # @param options [Hash] Connection options
        def initialize(symbols: [], **options)
          cfg = DhanHQ.configuration
          url = options[:url] || build_market_depth_url(cfg)
          super(url: url, **options)

          @symbols = Array(symbols)
          @subscriptions = Concurrent::Map.new
          @instrument_cache = Concurrent::Map.new
          @decoder = Decoder.new
        end

        ##
        # Start the Market Depth WebSocket connection
        # @return [Client] self for method chaining
        def start
          super
          subscribe_to_symbols(@symbols) if @symbols.any?
          self
        end

        ##
        # Subscribe to market depth for specific symbols
        # @param symbols [Array<String, Hash>] Symbols (or metadata hashes) to subscribe to
        # @return [Client] self for method chaining
        def subscribe(symbols)
          subscribe_to_symbols(Array(symbols))
          self
        end

        ##
        # Unsubscribe from market depth for specific symbols
        # @param symbols [Array<String, Hash>] Symbols (or metadata hashes) to unsubscribe from
        # @return [Client] self for method chaining
        def unsubscribe(symbols)
          unsubscribe_from_symbols(Array(symbols))
          self
        end

        ##
        # Get current subscriptions
        # @return [Array<String>] Currently subscribed symbol labels
        def subscriptions
          @subscriptions.values.map { |meta| meta[:original_label] }
        end

        ##
        # Check if subscribed to a symbol
        # @param symbol [String, Hash] Symbol or metadata hash to check
        # @return [Boolean] true if subscribed
        def subscribed?(symbol)
          @subscriptions.key?(normalize_label(symbol))
        end

        private

        ##
        # Build Market Depth WebSocket URL
        # @param config [Configuration] DhanHQ configuration
        # @return [String] WebSocket URL
        def build_market_depth_url(config)
          token = config.resolved_access_token
          raise DhanHQ::AuthenticationError, "Missing access token" if token.nil? || token.empty?
          cid = config.client_id or raise "DhanHQ.client_id not set"
          depth_level = config.market_depth_level || 20 # Default to 20 level depth

          if depth_level == 200
            "wss://full-depth-api.dhan.co/twohundreddepth?token=#{token}&clientId=#{cid}&authType=2"
          else
            "wss://depth-api-feed.dhan.co/twentydepth?token=#{token}&clientId=#{cid}&authType=2"
          end
        end

        ##
        # Run WebSocket session for Market Depth
        # @return [Array<Boolean>] [failed, got_429]
        def run_session
          failed = false
          got_429 = false

          EM.run do
            @ws = Faye::WebSocket::Client.new(@url, nil, headers: default_headers)

            @ws.on :open do |_|
              handle_open
            end

            @ws.on :message do |ev|
              handle_message(ev)
            end

            @ws.on :close do |ev|
              failed, got_429 = handle_close(ev)
              EM.stop
            end

            @ws.on :error do |ev|
              failed, got_429 = handle_error(ev)
              EM.stop
            end
          end

          [failed, got_429]
        end

        ##
        # Process incoming WebSocket message
        # @param data [String] Raw message data
        def process_message(data)
          depth_data = @decoder.decode(data)
          return unless depth_data

          emit(:depth_update, depth_data)
          emit(:raw_depth, data) # For debugging
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth] Error processing message: #{e.class} #{e.message}")
          emit(:error, e)
        end

        ##
        # Subscribe to symbols
        # @param symbols [Array<String, Hash>] Symbols to subscribe to
        def subscribe_to_symbols(symbols)
          symbols.each do |symbol|
            resolution = resolve_symbol(symbol)
            next unless resolution

            label = resolution[:label]
            next if @subscriptions.key?(label)

            subscription_message = {
              "RequestCode" => SUBSCRIBE_REQUEST_CODE,
              "InstrumentCount" => 1,
              "InstrumentList" => [
                {
                  "ExchangeSegment" => resolution[:exchange_segment],
                  "SecurityId" => resolution[:security_id]
                }
              ]
            }

            send_message(subscription_message)
            @subscriptions[label] = resolution
            DhanHQ.logger&.info("[DhanHQ::WS::MarketDepth] Subscribed to #{resolution[:original_label]} (#{resolution[:exchange_segment]}:#{resolution[:security_id]})")
          rescue StandardError => e
            DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth] Subscription error for #{symbol.inspect}: #{e.class} #{e.message}")
          end
        end

        ##
        # Unsubscribe from symbols
        # @param symbols [Array<String, Hash>] Symbols to unsubscribe from
        def unsubscribe_from_symbols(symbols)
          symbols.each do |symbol|
            label = normalize_label(symbol)
            security_data = @subscriptions[label]
            next unless security_data

            unsubscribe_message = {
              "RequestCode" => UNSUBSCRIBE_REQUEST_CODE,
              "InstrumentCount" => 1,
              "InstrumentList" => [
                {
                  "ExchangeSegment" => security_data[:exchange_segment],
                  "SecurityId" => security_data[:security_id]
                }
              ]
            }

            send_message(unsubscribe_message)
            @subscriptions.delete(label)
            DhanHQ.logger&.info("[DhanHQ::WS::MarketDepth] Unsubscribed from #{security_data[:original_label]} (#{security_data[:exchange_segment]}:#{security_data[:security_id]})")
          rescue StandardError => e
            DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth] Unsubscribe error for #{symbol.inspect}: #{e.class} #{e.message}")
          end
        end

        ##
        # Resolve symbol to security_id and exchange_segment using the instrument API
        # @param symbol [String, Hash] Trading symbol or metadata hash
        # @return [Hash, nil] Resolved instrument metadata
        def resolve_symbol(symbol)
          label = normalize_label(symbol)

          return @subscriptions[label] if @subscriptions.key?(label)

          from_hash = resolve_hash_symbol(symbol, label)
          return from_hash if from_hash

          symbol_str = symbol.to_s
          segment_hint, symbol_code = extract_segment_and_symbol(symbol_str)
          return nil unless symbol_code && !symbol_code.strip.empty?

          instrument = find_instrument(symbol_code, segment_hint)
          unless instrument
            DhanHQ.logger&.warn(
              "[DhanHQ::WS::MarketDepth] Unable to locate instrument for #{symbol_code} (segment hint: #{segment_hint || "AUTO"})"
            )
            return nil
          end

          build_resolution(instrument, label, symbol_str)
        end

        def resolve_hash_symbol(symbol, label)
          return nil unless symbol.is_a?(Hash)

          exchange_segment = symbol[:exchange_segment] || symbol[:segment] || symbol[:exchange]
          security_id = symbol[:security_id] || symbol[:token]
          normalized_segment = exchange_segment&.to_s&.strip&.upcase

          if security_id && normalized_segment
            original_label = symbol[:symbol] || symbol[:symbol_name] || symbol[:name] || security_id
            return {
              label: label,
              original_label: original_label.to_s,
              exchange_segment: normalized_segment,
              security_id: security_id.to_s,
              display_name: symbol[:display_name],
              symbol: original_label.to_s,
              original_input: symbol
            }
          end

          if security_id
            instrument = find_instrument(security_id.to_s, normalized_segment)
            return build_resolution(instrument, label, security_id) if instrument
          end

          symbol_code = symbol[:symbol] || symbol[:symbol_name] || symbol[:name]
          return nil unless symbol_code

          instrument = find_instrument(symbol_code.to_s, normalized_segment)
          build_resolution(instrument, label, symbol_code) if instrument
        end

        def build_resolution(instrument, label, original_label)
          return nil unless instrument

          fallback_label = original_label.to_s.strip.empty? ? instrument.symbol_name.to_s : original_label.to_s

          {
            label: label,
            original_label: fallback_label,
            exchange_segment: instrument.exchange_segment.to_s,
            security_id: instrument.security_id.to_s,
            display_name: instrument.display_name,
            symbol: instrument.symbol_name,
            original_input: original_label
          }
        end

        def extract_segment_and_symbol(symbol)
          parts = symbol.to_s.split(":", 2).map(&:strip)
          if parts.size == 2
            [parts[0].upcase, parts[1]]
          else
            [nil, symbol.strip]
          end
        end

        def normalize_label(symbol)
          case symbol
          when Hash
            symbol_label_from_hash(symbol)
          else
            symbol.to_s.strip.upcase
          end
        end

        def symbol_label_from_hash(symbol)
          seg = symbol[:exchange_segment] || symbol[:segment] || symbol[:exchange]
          sym = symbol[:symbol] || symbol[:symbol_name] || symbol[:name] || symbol[:security_id]
          base_label = sym ? sym.to_s : symbol[:security_id].to_s
          label = seg ? "#{seg}:#{base_label}" : base_label
          label.strip.upcase
        end

        def find_instrument(symbol_code, segment_hint)
          candidates = if segment_hint
                         [segment_hint.to_s.strip.upcase]
                       else
                         segment_priority
                       end

          normalized_code = symbol_code.to_s.strip.upcase
          candidates.each do |segment|
            next if segment.nil? || segment.empty?

            instrument = instrument_index(segment)[normalized_code]
            return instrument if instrument

            alt_code = normalized_code.gsub(/\s+/, " ")
            instrument = instrument_index(segment)[alt_code]
            return instrument if instrument
          end

          nil
        end

        def instrument_index(segment)
          @instrument_cache.compute_if_absent(segment) do
            build_instrument_index(segment)
          end
        rescue NoMethodError
          # Concurrent::Map#compute_if_absent is available on recent versions.
          # Fallback to fetch-or-store semantics if absent.
          @instrument_cache[segment] ||= build_instrument_index(segment)
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth] Instrument index error for #{segment}: #{e.class} #{e.message}")
          {}
        end

        def build_instrument_index(segment)
          records = DhanHQ::Models::Instrument.by_segment(segment)
          index = {}
          records.each do |instrument|
            keys_for(instrument).each do |key|
              index[key] ||= instrument
            end
          end
          index
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth] Failed to download instruments for #{segment}: #{e.class} #{e.message}")
          {}
        end

        def keys_for(instrument)
          keys = []
          symbol_name = instrument.symbol_name.to_s.strip.upcase
          display_name = instrument.display_name.to_s.strip.upcase
          security_id = instrument.security_id.to_s.strip.upcase
          keys << symbol_name unless symbol_name.empty?
          keys << display_name unless display_name.empty? || display_name == symbol_name
          keys << security_id unless security_id.empty?
          if instrument.respond_to?(:series) && instrument.series
            series_key = "#{symbol_name}:#{instrument.series}".strip.upcase
            keys << series_key unless series_key.empty?
          end
          keys
        end

        def segment_priority
          @segment_priority ||= begin
            preferred = [
              DhanHQ::Constants::NSE,
              DhanHQ::Constants::BSE,
              DhanHQ::Constants::NSE_FNO,
              DhanHQ::Constants::BSE_FNO,
              DhanHQ::Constants::INDEX
            ]
            (preferred + DhanHQ::Constants::EXCHANGE_SEGMENTS).compact.map(&:to_s).map(&:upcase).uniq
          end
        end
      end
    end
  end
end
