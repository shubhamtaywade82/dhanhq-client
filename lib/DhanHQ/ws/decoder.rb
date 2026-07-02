# frozen_string_literal: true

require_relative "websocket_packet_parser"
require_relative "segments"

module DhanHQ
  module WS
    # Translates the binary WebSocket frames into Ruby hashes that can be
    # consumed by client code.
    class Decoder
      # Mapping of feed response codes to semantic event kinds.
      FEED_KIND = {
        2 => :ticker, 4 => :quote, 5 => :oi, 6 => :prev_close, 8 => :full, 50 => :disconnect, 41 => :depth_bid, 51 => :depth_ask
      }.freeze

      # Parses a binary packet and returns a normalized hash representation.
      #
      # @param binary [String] Raw WebSocket frame payload.
      # @return [Hash, nil] Normalized tick data or nil when the packet should
      #   be ignored.
      def self.decode(binary)
        pkt = WebsocketPacketParser.new(binary).parse
        return nil if pkt.nil? || pkt.empty?

        kind   = FEED_KIND[pkt[:feed_response_code]] || :unknown
        segstr = Segments.from_code(pkt[:exchange_segment])
        sid    = pkt[:security_id].to_s

        dispatch(pkt, kind, segstr, sid)
      rescue StandardError => e
        DhanHQ.logger&.debug("[DhanHQ::WS::Decoder] #{e.class}: #{e.message}")
        nil
      end

      class << self
        private

        def dispatch(pkt, kind, segstr, sid)
          case kind
          when :ticker      then decode_ticker(pkt, segstr, sid)
          when :quote       then decode_quote(pkt, segstr, sid)
          when :full        then decode_full(pkt, segstr, sid)
          when :oi          then decode_oi(pkt, segstr, sid)
          when :prev_close  then decode_prev_close(pkt, segstr, sid)
          when :depth_bid, :depth_ask then decode_depth(pkt, kind, segstr, sid)
          when :disconnect then handle_disconnect(pkt, segstr, sid)
          else handle_unknown(pkt)
          end
        end

        def decode_ticker(pkt, segstr, sid)
          {
            kind: :ticker, segment: segstr, security_id: sid,
            ltp: pkt[:ltp].to_f, ts: pkt[:ltt]&.to_i
          }
        end

        def decode_quote(pkt, segstr, sid)
          {
            kind: :quote, segment: segstr, security_id: sid,
            ltp: pkt[:ltp].to_f, ts: pkt[:ltt]&.to_i, atp: pkt[:atp].to_f,
            vol: pkt[:volume].to_i, ts_buy_qty: pkt[:total_buy_qty].to_i, ts_sell_qty: pkt[:total_sell_qty].to_i,
            day_open: pkt[:day_open]&.to_f, day_high: pkt[:day_high]&.to_f, day_low: pkt[:day_low]&.to_f, day_close: pkt[:day_close]&.to_f
          }
        end

        def decode_full(pkt, segstr, sid)
          out = {
            kind: :full, segment: segstr, security_id: sid,
            ltp: pkt[:ltp].to_f, ts: pkt[:ltt]&.to_i, atp: pkt[:atp].to_f,
            vol: pkt[:volume].to_i, ts_buy_qty: pkt[:total_buy_qty].to_i, ts_sell_qty: pkt[:total_sell_qty].to_i,
            oi: pkt[:open_interest]&.to_i, oi_high: pkt[:highest_open_interest]&.to_i, oi_low: pkt[:lowest_open_interest]&.to_i,
            day_open: pkt[:day_open]&.to_f, day_high: pkt[:day_high]&.to_f, day_low: pkt[:day_low]&.to_f, day_close: pkt[:day_close]&.to_f
          }
          merge_depth(out, pkt[:market_depth])
          out
        end

        def decode_oi(pkt, segstr, sid)
          { kind: :oi, segment: segstr, security_id: sid, oi: pkt[:open_interest].to_i }
        end

        def decode_prev_close(pkt, segstr, sid)
          { kind: :prev_close, segment: segstr, security_id: sid, prev_close: pkt[:prev_close].to_f,
            oi_prev: pkt[:oi_prev].to_i }
        end

        def decode_depth(pkt, kind, segstr, sid)
          {
            kind: kind, segment: segstr, security_id: sid,
            bid_quantity: pkt[:bid_quantity], ask_quantity: pkt[:ask_quantity],
            no_of_bid_orders: pkt[:no_of_bid_orders], no_of_ask_orders: pkt[:no_of_ask_orders],
            bid: pkt[:bid_price], ask: pkt[:ask_price]
          }
        end

        def handle_disconnect(pkt, segstr, sid)
          DhanHQ.logger&.warn("[DhanHQ::WS] disconnect code=#{pkt[:disconnection_code]} seg=#{segstr} sid=#{sid}")
          nil
        end

        def handle_unknown(pkt)
          DhanHQ.logger&.debug("[DhanHQ::WS] unknown feed kind code=#{pkt[:feed_response_code]}")
          nil
        end

        def merge_depth(out, market_depth)
          return unless market_depth.respond_to?(:[]) && market_depth[0]

          lvl = market_depth[0]
          out[:bid] = lvl.respond_to?(:bid_price) ? lvl.bid_price.to_f : nil
          out[:ask] = lvl.respond_to?(:ask_price) ? lvl.ask_price.to_f : nil
          return unless lvl.respond_to?(:bid_quantity) && lvl.respond_to?(:ask_quantity)

          out[:bid_qty] = lvl.bid_quantity.to_i
          out[:ask_qty] = lvl.ask_quantity.to_i
        end
      end
    end
  end
end
