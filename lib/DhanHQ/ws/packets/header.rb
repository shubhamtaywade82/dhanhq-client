# frozen_string_literal: true

require "bindata"

module DhanHQ
  module WS
    module Packets
      class Header < BinData::Record
        endian :big # Default to big-endian for majority fields

        uint8  :feed_response_code     # Byte 1
        uint16 :message_length         # Bytes 2–3
        uint8  :exchange_segment       # Byte 4

        # Parse security_id separately using little-endian
        # This works because `BinData` allows override
        int32le :security_id # Bytes 5–8
      end
    end
  end
end
