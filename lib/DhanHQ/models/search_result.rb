# frozen_string_literal: true

module DhanHQ
  module Models
    # Lightweight result returned by Instrument.search for agent-friendly security resolution.
    class SearchResult < BaseModel
      attributes :security_id, :symbol_name, :display_name, :exchange_segment, :instrument,
                 :instrument_type, :lot_size, :tick_size, :expiry_date, :strike_price,
                 :option_type, :underlying_symbol, :isin
    end
  end
end
