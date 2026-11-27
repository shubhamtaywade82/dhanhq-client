# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    # Binary structures backing the streaming feed decoder.
    module Packets
      # Binary representation of the 8-byte frame header.
      #
      # Per the official Live Market Feed spec the header is LITTLE-ENDIAN
      # throughout: responseCode (1 byte), messageLength (2 bytes), then the
      # exchange segment (1 byte) and security id (4 bytes).
      class Header < BinData::Record
        endian :little

        uint8  :feed_response_code     # Byte 1
        uint16 :message_length         # Bytes 2–3
        uint8  :exchange_segment       # Byte 4
        int32  :security_id            # Bytes 5–8
      end
    end
  end
end
