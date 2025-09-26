# frozen_string_literal: true

require "eventmachine"
require "faye/websocket"
require "json"

module DhanHQ
  module WS
    module Orders
      class Connection
        COOL_OFF_429 = 60
        MAX_BACKOFF  = 90

        def initialize(url:, &on_json)
          @url           = url
          @on_json       = on_json
          @ws            = nil
          @stop          = false
          @cooloff_until = nil
        end

        def start
          Thread.new { loop_run }
          self
        end

        def stop
          @stop = true
          @ws&.close
        end

        def disconnect!
          # spec does not list a separate disconnect message; just close
          @ws&.close
        end

        private

        def loop_run
          backoff = 2.0
          until @stop
            failed  = false
            got_429 = false
            sleep (@cooloff_until - Time.now).ceil if @cooloff_until && Time.now < @cooloff_until

            begin
              EM.run do
                @ws = Faye::WebSocket::Client.new(@url, nil, headers: default_headers)

                @ws.on :open do |_|
                  DhanHQ.logger&.info("[DhanHQ::WS::Orders] open")
                  send_login
                end

                @ws.on :message do |ev|
                  msg = JSON.parse(ev.data, symbolize_names: true)
                  @on_json&.call(msg)
                rescue StandardError => e
                  DhanHQ.logger&.error("[DhanHQ::WS::Orders] bad JSON #{e.class}: #{e.message}")
                end

                @ws.on :close do |ev|
                  DhanHQ.logger&.warn("[DhanHQ::WS::Orders] close #{ev.code} #{ev.reason}")
                  failed  = (ev.code != 1000)
                  got_429 = ev.reason.to_s.include?("429")
                  EM.stop
                end

                @ws.on :error do |ev|
                  DhanHQ.logger&.error("[DhanHQ::WS::Orders] error #{ev.message}")
                  failed = true
                end
              end
            rescue StandardError => e
              DhanHQ.logger&.error("[DhanHQ::WS::Orders] crashed #{e.class} #{e.message}")
              failed = true
            ensure
              break if @stop

              if got_429
                @cooloff_until = Time.now + COOL_OFF_429
                DhanHQ.logger&.warn("[DhanHQ::WS::Orders] cooling off #{COOL_OFF_429}s due to 429")
              end
              if failed
                sleep_time = [backoff, MAX_BACKOFF].min
                jitter = rand(0.2 * sleep_time)
                DhanHQ.logger&.warn("[DhanHQ::WS::Orders] reconnecting in #{(sleep_time + jitter).round(1)}s")
                sleep(sleep_time + jitter)
                backoff *= 2.0
              else
                backoff = 2.0
              end
            end
          end
        end

        def default_headers
          { "User-Agent" => "dhanhq-ruby/#{defined?(DhanHQ::VERSION) ? DhanHQ::VERSION : "dev"} Ruby/#{RUBY_VERSION}" }
        end

        def send_login
          cfg = DhanHQ.configuration
          if cfg.ws_user_type.to_s.upcase == "PARTNER"
            payload = {
              LoginReq: { MsgCode: 42, ClientId: cfg.partner_id },
              UserType: "PARTNER",
              Secret: cfg.partner_secret
            }
          else
            token = cfg.access_token or raise "DhanHQ.access_token not set"
            cid   = cfg.client_id    or raise "DhanHQ.client_id not set"
            payload = {
              LoginReq: { MsgCode: 42, ClientId: cid, Token: token },
              UserType: "SELF"
            }
          end
          DhanHQ.logger&.info("[DhanHQ::WS::Orders] LOGIN -> (#{payload[:UserType]})")
          @ws.send(payload.to_json)
        end
      end
    end
  end
end
