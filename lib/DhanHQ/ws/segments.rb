# frozen_string_literal: true

module DhanHQ
  module WS
    module Segments
      # Canonical enum mapping (per Dhan spec)
      STRING_TO_CODE = {
        "IDX_I" => 0,
        "NSE_EQ" => 1,
        "NSE_FNO" => 2,
        "NSE_CURRENCY" => 3,
        "BSE_EQ" => 4,
        "MCX_COMM" => 5,
        "BSE_CURRENCY" => 7,
        "BSE_FNO" => 8
      }.freeze

      CODE_TO_STRING = STRING_TO_CODE.invert.freeze

      # Accept "NSE_FNO"/:nse_fno/2/"2" and return the STRING Dhan expects in requests.
      def self.to_request_string(segment)
        case segment
        when String
          return segment if STRING_TO_CODE.key?(segment) # already canonical
          return CODE_TO_STRING[segment.to_i] if /\A\d+\z/.match?(segment) # "2" -> "NSE_FNO"

          STRING_TO_CODE.key(segment) || segment.upcase # e.g. "nse_fno" -> "NSE_FNO"
        when Symbol
          up = segment.to_s.upcase
          STRING_TO_CODE.key(STRING_TO_CODE[up]) || up
        when Integer
          CODE_TO_STRING[segment] || segment.to_s
        else
          segment.to_s
        end
      end

      # Normalize a single instrument for subscribe/unsubscribe requests.
      # Ensures:
      #   - ExchangeSegment is a STRING enum (e.g., "NSE_FNO")
      #   - SecurityId is a STRING
      def self.normalize_instrument(h)
        seg = to_request_string(h[:ExchangeSegment] || h["ExchangeSegment"])
        sid = (h[:SecurityId] || h["SecurityId"]).to_s
        { ExchangeSegment: seg, SecurityId: sid }
      end

      def self.normalize_instruments(list)
        Array(list).map { |h| normalize_instrument(h) }
      end

      # Convert response header's segment code (byte) -> enum string
      def self.from_code(code_byte)
        CODE_TO_STRING[code_byte] || code_byte.to_s
      end
    end
  end
end
