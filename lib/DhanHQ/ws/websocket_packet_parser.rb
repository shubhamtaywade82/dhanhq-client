# frozen_string_literal: true

require "stringio"

require_relative "packets/header"
require_relative "packets/ticker_packet"
require_relative "packets/quote_packet"
require_relative "packets/full_packet"
require_relative "packets/oi_packet"
require_relative "packets/prev_close_packet"
require_relative "packets/disconnect_packet"
require_relative "packets/index_packet"
require_relative "packets/market_status_packet"
# optional:
require_relative "packets/depth_delta_packet"

module DhanHQ
  module WS
    # Parses raw WebSocket frames using the binary packet definitions.
    class WebsocketPacketParser
      # Numeric feed codes emitted by the streaming service.
      RESPONSE_CODES = {
        index: 1,
        ticker: 2,
        quote: 4,
        oi: 5,
        prev_close: 6,
        full: 8,
        depth_bid: 41,
        depth_ask: 51,
        disconnect: 50
      }.freeze

      attr_reader :binary_data, :binary_stream, :header

      def initialize(binary_data)
        @binary_data   = binary_data
        @header        = Packets::Header.read(@binary_data) # 8 bytes header
        @binary_stream = StringIO.new(@binary_data.byteslice(8..) || "".b) # payload only
      end

      # Parses the supplied binary frame and returns a normalized hash.
      #
      # @return [Hash]
      def parse
        body =
          case header.feed_response_code
          when RESPONSE_CODES[:index]       then parse_index
          when RESPONSE_CODES[:ticker]      then parse_ticker
          when RESPONSE_CODES[:quote]       then parse_quote
          when RESPONSE_CODES[:oi]          then parse_oi
          when RESPONSE_CODES[:prev_close]  then parse_prev_close
          when RESPONSE_CODES[:market_status] then parse_market_status
          when RESPONSE_CODES[:full]        then parse_full
          when RESPONSE_CODES[:depth_bid]   then parse_depth(:bid)
          when RESPONSE_CODES[:depth_ask]   then parse_depth(:ask)
          when RESPONSE_CODES[:disconnect]  then parse_disconnect
          else
            DhanHQ.logger&.debug("[WS::Parser] Unknown feed code=#{header.feed_response_code}")
            {}
          end

        {
          feed_response_code: header.feed_response_code,
          message_length: header.message_length,
          exchange_segment: header.exchange_segment, # numeric (0/1/2/…)
          security_id: header.security_id
        }.merge(body)
      rescue StandardError => e
        DhanHQ.logger.error "[WS::Parser] ❌ #{e.class}: #{e.message}"
        {}
      end

      private

      def parse_index
        rec = Packets::IndexPacket.new(@binary_stream.string)
        { index_raw: rec.raw } # keep raw until official layout is known
      end

      def parse_market_status
        rec = Packets::MarketStatusPacket.new(@binary_stream.string)
        { market_status_raw: rec.raw } # keep raw until official layout is known
      end

      def parse_ticker
        rec = Packets::TickerPacket.read(@binary_stream.string)
        { ltp: rec.ltp, ltt: rec.ltt }
      end

      def parse_quote
        rec = Packets::QuotePacket.read(@binary_stream.string)

        {
          ltp: rec.ltp,
          last_trade_qty: rec.last_trade_qty,
          ltt: rec.ltt,
          atp: rec.atp,
          volume: rec.volume,
          total_sell_qty: rec.total_sell_qty,
          total_buy_qty: rec.total_buy_qty,
          day_open: rec.day_open,
          day_close: rec.day_close,
          day_high: rec.day_high,
          day_low: rec.day_low
        }
      end

      def parse_full
        rec = Packets::FullPacket.read(@binary_stream.string)
        {
          ltp: rec.ltp,
          last_trade_qty: rec.last_trade_qty,
          ltt: rec.ltt,
          atp: rec.atp,
          volume: rec.volume,
          total_sell_qty: rec.total_sell_qty,
          total_buy_qty: rec.total_buy_qty,
          open_interest: rec.open_interest,
          highest_open_interest: rec.highest_oi,
          lowest_open_interest: rec.lowest_oi,
          day_open: rec.day_open,
          day_close: rec.day_close,
          day_high: rec.day_high,
          day_low: rec.day_low,
          market_depth: rec.market_depth
        }
      end

      def parse_oi
        rec = Packets::OiPacket.read(@binary_stream.string)
        { open_interest: rec.open_interest }
      end

      def parse_prev_close
        rec = Packets::PrevClosePacket.read(@binary_stream.string)
        { prev_close: rec.prev_close, oi_prev: rec.oi_prev }
      end

      # depth_bid / depth_ask incremental
      def parse_depth(side)
        rec = Packets::DepthDeltaPacket.read(@binary_stream.string)
        {
          depth_side: side,
          bid_quantity: rec.bid_quantity,
          ask_quantity: rec.ask_quantity,
          no_of_bid_orders: rec.no_of_bid_orders,
          no_of_ask_orders: rec.no_of_ask_orders,
          bid_price: rec.bid_price,
          ask_price: rec.ask_price
        }
      end

      def parse_disconnect
        {
          disconnection_code: binary_stream.read(2).unpack1("s>")
        }
      end

      def debug_log(data)
        DhanHQ.logger.debug { "[WS::Parser] Parsed: #{data.inspect}" }
      end
    end
  end
end
