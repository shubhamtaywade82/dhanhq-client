# frozen_string_literal: true

require_relative "../base_connection"

module DhanHQ
  module WS
    module Orders
      ##
      # WebSocket connection for real-time order updates
      # Inherits from BaseConnection for consistent behavior
      class Connection < BaseConnection
        ##
        # Initialize Orders WebSocket connection
        # @param url [String] WebSocket endpoint URL
        # @param options [Hash] Connection options
        def initialize(url:, **options)
          super
        end

        private

        ##
        # Run WebSocket session for Orders
        # @return [Array<Boolean>] [failed, got_429]
        def run_session
          failed = false
          got_429 = false
          latch = Queue.new

          runner = proc do |stopper|
            @ws = Faye::WebSocket::Client.new(@url, nil, headers: default_headers)

            @ws.on :open do |_|
              handle_open
              authenticate
            end

            @ws.on :message do |ev|
              handle_message(ev)
            end

            @ws.on :close do |ev|
              failed, got_429 = handle_close(ev)
              latch << true
              stopper.call
            end

            @ws.on :error do |ev|
              failed, got_429 = handle_error(ev)
            end
          end

          if EM.reactor_running?
            EM.schedule { runner.call(-> {}) }
          else
            EM.run do
              runner.call(-> { EM.stop })
            end
          end

          latch.pop
          [failed, got_429]
        end

        ##
        # Process incoming WebSocket message
        # @param ev [Event] WebSocket message event
        def handle_message(ev)
          msg = JSON.parse(ev.data, symbolize_names: true)
          emit(:raw, msg)
          emit(:message, msg)
        rescue JSON::ParserError => e
          DhanHQ.logger&.error("[DhanHQ::WS::Orders] Bad JSON #{e.class}: #{e.message}")
          emit(:error, e)
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::Orders] Message processing error: #{e.class} #{e.message}")
          emit(:error, e)
        end

        ##
        # Authenticate with DhanHQ Orders WebSocket
        def authenticate
          cfg = DhanHQ.configuration

          if cfg.ws_user_type.to_s.upcase == "PARTNER"
            payload = {
              LoginReq: { MsgCode: 42, ClientId: cfg.partner_id },
              UserType: "PARTNER",
              Secret: cfg.partner_secret
            }
          else
            token = cfg.access_token or raise "DhanHQ.access_token not set"
            cid = cfg.client_id or raise "DhanHQ.client_id not set"
            payload = {
              LoginReq: { MsgCode: 42, ClientId: cid, Token: token },
              UserType: "SELF"
            }
          end

          DhanHQ.logger&.info("[DhanHQ::WS::Orders] LOGIN -> (#{payload[:UserType]})")
          send_message(payload)
        end
      end
    end
  end
end
