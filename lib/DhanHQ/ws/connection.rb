# frozen_string_literal: true

require "eventmachine"
require "faye/websocket"
require "json"

module DhanHQ
  module WS
    class Connection
      SUB_CODES   = { ticker: 15, quote: 17, full: 21 }.freeze # adjust if needed
      UNSUB_CODES = { ticker: 16, quote: 18, full: 22 }.freeze

      COOL_OFF_429 = 60  # seconds to cool off on 429
      MAX_BACKOFF  = 90  # cap exponential backoff

      attr_reader :stopping

      def initialize(url:, mode:, bus:, state:, &on_binary)
        @url = url
        @mode = mode
        @bus = bus
        @state = state
        @on_binary = on_binary
        @stop = false
        @stopping = false
        @ws     = nil
        @timer  = nil
        @cooloff_until = nil
        @thr = nil
      end

      def start
        return self if @thr&.alive?

        @thr = Thread.new { loop_run }
        self
      end

      # Hard stop: no graceful packet, just close and never reconnect
      def stop
        @stop = true
        @stopping = true
        if @ws
          begin
            @ws.close
          rescue StandardError
          end
        end
        self
      end

      # Public API: explicit disconnect (send RequestCode 12) and close socket
      # Graceful broker disconnect (RequestCode 12), then no reconnect
      def disconnect!
        @stop = true
        @stopping = true
        begin
          send_disconnect
        rescue StandardError
        ensure
          @ws&.close
        end
        self
      end

      # Is underlying socket open?
      def open?
        @ws && @ws.instance_variable_get(:@driver)&.ready_state == 1
      rescue StandardError
        false
      end

      private

      def loop_run
        backoff = 2.0
        until @stop
          failed = false
          got_429 = false # rubocop:disable Naming/VariableNumber

          # respect any active cool-off window
          sleep (@cooloff_until - Time.now).ceil if @cooloff_until && Time.now < @cooloff_until

          begin
            EM.run do
              @ws = Faye::WebSocket::Client.new(@url, nil, headers: default_headers)

              @ws.on :open do |_|
                DhanHQ.logger&.info("[DhanHQ::WS] open")
                # re-subscribe snapshot on reconnect
                snapshot = @state.snapshot.map do |k|
                  seg, sid = k.split(":")
                  { ExchangeSegment: seg, SecurityId: sid }
                end
                send_sub(snapshot) unless snapshot.empty?
                @timer = EM.add_periodic_timer(0.25) { drain_and_send }
              end

              @ws.on :message do |ev|
                @on_binary&.call(ev.data) # raw frames to decoder
              end

              @ws.on :close do |ev|
                # If we initiated stop/disconnect, DO NOT reconnect regardless of code.
                EM.cancel_timer(@timer) if @timer
                @timer = nil
                msg = "[DhanHQ::WS] close #{ev.code} #{ev.reason}"
                DhanHQ.logger&.warn(msg)

                if @stopping
                  failed = false
                else
                  failed  = (ev.code != 1000)
                  got_429 = ev.reason.to_s.include?("429")
                end
                EM.stop
              end

              @ws.on :error do |ev|
                DhanHQ.logger&.error("[DhanHQ::WS] error #{ev.message}")
                failed = true
              end
            end
          rescue StandardError => e
            DhanHQ.logger&.error("[DhanHQ::WS] crashed #{e.class} #{e.message}")
            failed = true
          ensure
            break if @stop

            if got_429
              @cooloff_until = Time.now + COOL_OFF_429
              DhanHQ.logger&.warn("[DhanHQ::WS] cooling off #{COOL_OFF_429}s due to 429")
            end

            if failed
              # exponential backoff with jitter
              sleep_time = [backoff, MAX_BACKOFF].min
              jitter = rand(0.2 * sleep_time)
              DhanHQ.logger&.warn("[DhanHQ::WS] reconnecting in #{(sleep_time + jitter).round(1)}s")
              sleep(sleep_time + jitter)
              backoff *= 2.0
            else
              backoff = 2.0 # reset only after a clean session end
            end
          end
        end
      end

      def default_headers
        { "User-Agent" => "dhanhq-ruby/#{defined?(DhanHQ::VERSION) ? DhanHQ::VERSION : "dev"} Ruby/#{RUBY_VERSION}" }
      end

      def drain_and_send
        cmds = @bus.drain
        return if cmds.empty?

        subs, unsubs = cmds.partition { |c| c.op == :sub }

        unless subs.empty?
          list     = uniq(flatten(subs.map(&:payload)))
          new_only = @state.want_sub(list)
          unless new_only.empty?
            send_sub(new_only)
            @state.mark_subscribed!(new_only)
          end
        end

        return if unsubs.empty?

        list       = uniq(flatten(unsubs.map(&:payload)))
        exist_only = @state.want_unsub(list)
        return if exist_only.empty?

        send_unsub(exist_only)
        @state.mark_unsubscribed!(exist_only)
      end

      def send_sub(list)
        return if list.empty?

        list.each_slice(100) do |chunk|
          payload = { RequestCode: SUB_CODES.fetch(@mode), InstrumentCount: chunk.size, InstrumentList: chunk }
          DhanHQ.logger&.info("[DhanHQ::WS] SUB -> +#{chunk.size} (total=#{list.size})")
          @ws.send(payload.to_json)
        end
      end

      def send_unsub(list)
        return if list.empty?

        list.each_slice(100) do |chunk|
          payload = { RequestCode: UNSUB_CODES.fetch(@mode), InstrumentCount: chunk.size, InstrumentList: chunk }
          DhanHQ.logger&.info("[DhanHQ::WS] UNSUB -> -#{chunk.size} (total=#{list.size})")
          @ws.send(payload.to_json)
        end
      end

      def send_disconnect
        return unless @ws

        payload = { RequestCode: 12 } # per Dhan: Disconnect Feed
        DhanHQ.logger&.info("[DhanHQ::WS] DISCONNECT -> #{payload}")
        @ws.send(payload.to_json)
      rescue StandardError => e
        DhanHQ.logger&.debug("[DhanHQ::WS] send_disconnect error #{e.class}: #{e.message}")
      end

      def flatten(a) = a.flatten

      def uniq(list)
        seen = {}
        list.each_with_object([]) do |i, out|
          k = "#{i[:ExchangeSegment]}:#{i[:SecurityId]}"
          next if seen[k]

          out << i
          seen[k] = true
        end
      end
    end
  end
end
