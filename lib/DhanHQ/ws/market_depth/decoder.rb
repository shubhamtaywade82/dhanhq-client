# frozen_string_literal: true

require_relative "../segments"

module DhanHQ
  module WS
    module MarketDepth
      ##
      # Decoder for the binary 20/200-level Full Market Depth feed.
      #
      # Wire format (docs.dhanhq.co "Full Market Depth", little-endian, no padding):
      #
      #   Header (12 bytes)
      #     0-1   int16   message length of the packet
      #     2     byte    feed response code: 41 = bid side, 51 = ask side, 50 = disconnect
      #     3     byte    exchange segment (Annexure numeric enum)
      #     4-7   int32   security id
      #     8-11  uint32  20-level: message sequence (ignored) / 200-level: number of rows
      #   Rows (16 bytes each; 20 for 20-level, "number of rows" for 200-level)
      #     0-7   float64 price
      #     8-11  uint32  quantity
      #     12-15 uint32  number of orders
      #
      # Bid and ask arrive as separate packets, and several packets (per side,
      # per instrument) are stacked in one WebSocket message, so {#decode}
      # walks the frame packet by packet using each header's length.
      class Decoder
        HEADER_SIZE = 12
        ROW_SIZE = 16
        BID_CODE = 41
        ASK_CODE = 51
        DISCONNECT_CODE = 50
        TWENTY_LEVEL_ROWS = 20

        # @param depth_level [Integer] 20 or 200; decides how header bytes 8-11 are read.
        def initialize(depth_level: 20)
          @depth_level = depth_level.to_i == 200 ? 200 : 20
        end

        ##
        # Decode one WebSocket message into its side packets.
        #
        # @param data [String, Array<Integer>] Raw frame (Faye delivers binary frames as byte arrays).
        # @return [Array<Hash>] One entry per packet, in wire order. Side packets are
        #   +{ type: :bid | :ask, exchange_segment:, security_id:, levels: [{ price:, quantity:, orders: }] }+;
        #   a disconnect packet is +{ type: :disconnect, exchange_segment:, security_id:, code: }+.
        #   Malformed trailing bytes are dropped (and logged), never raised.
        def decode(data)
          bytes = to_binary(data)
          packets = []
          offset = 0

          while bytes.bytesize - offset >= HEADER_SIZE
            packet, consumed = read_packet(bytes, offset)
            break unless packet

            packets << packet
            offset += consumed
          end

          log_trailing(bytes.bytesize - offset) if offset < bytes.bytesize
          packets
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth::Decoder] Decode error: #{e.class} #{e.message}")
          []
        end

        private

        def to_binary(data)
          return "".b if data.nil?

          data.is_a?(Array) ? data.pack("C*") : data.to_s.b
        end

        # @return [Array(Hash, Integer), nil] The packet and the bytes it spans.
        def read_packet(bytes, offset)
          length, code, segment, security_id, tail = bytes.byteslice(offset, HEADER_SIZE).unpack("s<CCl<L<")
          segment_name = Segments.from_code(segment)

          return [disconnect(bytes, offset, segment_name, security_id), packet_span(length, HEADER_SIZE + 2)] if code == DISCONNECT_CODE

          unless [BID_CODE, ASK_CODE].include?(code)
            DhanHQ.logger&.warn("[DhanHQ::WS::MarketDepth::Decoder] Unknown response code #{code}; dropping rest of frame")
            return nil
          end

          rows = @depth_level == 200 ? tail : TWENTY_LEVEL_ROWS
          span = side_span(length, rows)
          available = [(bytes.bytesize - offset - HEADER_SIZE) / ROW_SIZE, rows, (span - HEADER_SIZE) / ROW_SIZE].min

          packet = {
            type: code == BID_CODE ? :bid : :ask,
            exchange_segment: segment_name,
            security_id: security_id.to_s,
            levels: read_levels(bytes, offset + HEADER_SIZE, available)
          }
          [packet, span]
        end

        # Packet span from the header's length field, falling back to the
        # documented fixed size when the field is absent or implausible.
        def packet_span(length, expected)
          length.to_i >= HEADER_SIZE ? length : expected
        end

        # The docs call the length field "message length of the entire payload
        # packet" without saying whether the 12-byte header is included. A value
        # equal to exactly the rows (rows * 16) is read as payload-only; anything
        # else as the full packet. Both readings stay aligned on stacked frames.
        def side_span(length, rows)
          payload = rows * ROW_SIZE
          return HEADER_SIZE + payload if length.to_i == payload

          packet_span(length, HEADER_SIZE + payload)
        end

        def read_levels(bytes, start, count)
          levels = Array.new([count, 0].max) do |i|
            price, quantity, orders = bytes.byteslice(start + (i * ROW_SIZE), ROW_SIZE).unpack("EL<L<")
            { price: price, quantity: quantity, orders: orders }
          end
          # Unfilled rows of a partially populated book are zeroed on the wire.
          levels.reject { |level| level[:quantity].zero? && level[:price].zero? }
        end

        def disconnect(bytes, offset, segment_name, security_id)
          code = bytes.byteslice(offset + HEADER_SIZE, 2)&.unpack1("s<")
          { type: :disconnect, exchange_segment: segment_name, security_id: security_id.to_s, code: code }
        end

        def log_trailing(count)
          DhanHQ.logger&.warn("[DhanHQ::WS::MarketDepth::Decoder] Ignoring #{count} trailing byte(s) in depth frame")
        end
      end
    end
  end
end
