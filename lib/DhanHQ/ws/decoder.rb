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

        # pp pkt
        case kind
        when :ticker
          {
            kind: :ticker, segment: segstr, security_id: sid,
            ltp: pkt[:ltp].to_f, ts: pkt[:ltt].to_i
          }
        when :quote
          {
            kind: :quote, segment: segstr, security_id: sid,
            ltp: pkt[:ltp].to_f, ts: pkt[:ltt].to_i, atp: pkt[:atp].to_f,
            vol: pkt[:volume].to_i, ts_buy_qty: pkt[:total_buy_qty].to_i, ts_sell_qty: pkt[:total_sell_qty].to_i,
            day_open: pkt[:day_open]&.to_f, day_high: pkt[:day_high]&.to_f, day_low: pkt[:day_low]&.to_f, day_close: pkt[:day_close]&.to_f
          }
        when :full
          out = {
            kind: :full, segment: segstr, security_id: sid,
            ltp: pkt[:ltp].to_f, ts: pkt[:ltt].to_i, atp: pkt[:atp].to_f,
            vol: pkt[:volume].to_i, ts_buy_qty: pkt[:total_buy_qty].to_i, ts_sell_qty: pkt[:total_sell_qty].to_i,
            oi: pkt[:open_interest]&.to_i, oi_high: pkt[:highest_open_interest]&.to_i, oi_low: pkt[:lowest_open_interest]&.to_i,
            day_open: pkt[:day_open]&.to_f, day_high: pkt[:day_high]&.to_f, day_low: pkt[:day_low]&.to_f, day_close: pkt[:day_close]&.to_f
          }
          # First depth level (if present)
          if (md = pkt[:market_depth]).respond_to?(:[]) && md[0]
            lvl = md[0]
            out[:bid] = lvl.respond_to?(:bid_price) ? lvl.bid_price.to_f : nil
            out[:ask] = lvl.respond_to?(:ask_price) ? lvl.ask_price.to_f : nil
          end
          out
        when :oi
          { kind: :oi, segment: segstr, security_id: sid, oi: pkt[:open_interest].to_i }
        when :prev_close
          { kind: :prev_close, segment: segstr, security_id: sid, prev_close: pkt[:prev_close].to_f,
            oi_prev: pkt[:oi_prev].to_i }
        when :depth_bid, :depth_ask
          {
            kind: kind, segment: segstr, security_id: sid,
            bid_quantity: pkt[:bid_quantity], ask_quantity: pkt[:ask_quantity],
            no_of_bid_orders: pkt[:no_of_bid_orders], no_of_ask_orders: pkt[:no_of_ask_orders],
            bid: pkt[:bid_price], ask: pkt[:ask_price]
          }
        when :disconnect
          DhanHQ.logger&.warn("[DhanHQ::WS] disconnect code=#{pkt[:disconnection_code]} seg=#{segstr} sid=#{sid}")
          nil
        else
          DhanHQ.logger&.debug("[DhanHQ::WS] unknown feed kind code=#{pkt[:feed_response_code]}")
          nil
        end
      rescue StandardError => e
        DhanHQ.logger&.debug("[DhanHQ::WS::Decoder] #{e.class}: #{e.message}")
        nil
      end
    end
  end
end
