# frozen_string_literal: true

require_relative "../segments"

module DhanHQ
  module WS
    module MarketDepth
      ##
      # Decoder for the Full Market Depth (FMD) WebSocket binary protocol.
      #
      # Wire format (all fields little-endian, per the official Dhan
      # "Full Market Depth" documentation):
      #
      #   12-byte frame header:
      #     0:  int16  message_length — total frame size including this header
      #     2:  uint8  response code  — 41 = bid frame, 51 = ask frame, 50 = disconnect
      #     3:  uint8  exchange segment
      #     4:  int32  security id
      #     8:  uint32 sequence number (ignore)
      #
      #   followed by N rows of 16 bytes (bid and ask frames carry one side each):
      #     0:  float64 price
      #     8:  uint32 quantity
      #     12: uint32 number of orders
      #
      # A 20-level frame is 12 + 20*16 = 332 bytes; a 200-level frame is 3212
      # bytes. A single WebSocket message may stack multiple frames back to
      # back — each frame's extent is given by its message_length, so frames
      # are split by consuming exactly that many bytes per iteration.
      class Decoder
        RESPONSE_CODES = { bid: 41, ask: 51, disconnect: 50 }.freeze
        HEADER_SIZE = 12
        ROW_SIZE = 16

        ##
        # Decode a raw WebSocket message into an array of frame hashes.
        #
        # @param data [String] Raw binary WebSocket message (may contain
        #   multiple stacked frames).
        # @return [Array<Hash>] One hash per frame:
        #   { security_id:, exchange_segment:, side:, levels: [{price:, quantity:, orders:}] }
        #   or { security_id:, exchange_segment:, side: :disconnect, disconnect_code: }
        def decode(data)
          return [] if data.nil? || data.empty?

          bytes = data.b
          frames = []
          offset = 0
          while offset + HEADER_SIZE <= bytes.bytesize
            frame, next_offset = parse_frame(bytes, offset)
            break if frame.nil?

            frames << frame
            offset = next_offset
          end
          frames
        rescue StandardError => e
          DhanHQ.logger&.error("[DhanHQ::WS::MarketDepth::Decoder] Decode error: #{e.class}: #{e.message}")
          []
        end

        private

        # Parses a single frame starting at +offset+ and returns
        # [frame_hash, next_offset], or [nil, offset] when the frame is truncated.
        def parse_frame(bytes, offset)
          message_length, code, segment, security_id = bytes.byteslice(offset, HEADER_SIZE).unpack("s<CCl<")
          return [nil, offset] if message_length.nil? || message_length <= HEADER_SIZE || offset + message_length > bytes.bytesize

          base = {
            security_id: security_id.to_s,
            exchange_segment: Segments.from_code(segment),
            message_length: message_length
          }

          case code
          when RESPONSE_CODES[:bid], RESPONSE_CODES[:ask]
            side = code == RESPONSE_CODES[:bid] ? :bid : :ask
            [base.merge(side: side, levels: parse_rows(bytes, offset + HEADER_SIZE, message_length)), offset + message_length]
          when RESPONSE_CODES[:disconnect]
            disconnect_code = bytes.byteslice(offset + HEADER_SIZE, 2)&.unpack1("v")
            [base.merge(side: :disconnect, disconnect_code: disconnect_code), offset + message_length]
          else
            DhanHQ.logger&.debug("[DhanHQ::WS::MarketDepth::Decoder] Unknown frame code=#{code}")
            [nil, offset]
          end
        end

        # Decodes the fixed-size price rows of a bid/ask frame.
        def parse_rows(bytes, start, message_length)
          row_bytes = message_length - HEADER_SIZE
          row_count = [row_bytes / ROW_SIZE, 0].max
          rows = []
          row_count.times do |i|
            price, quantity, orders = bytes.byteslice(start + (i * ROW_SIZE), ROW_SIZE).unpack("EVV")
            rows << { price: price, quantity: quantity, orders: orders }
          end
          rows
        end
      end
    end
  end
end
