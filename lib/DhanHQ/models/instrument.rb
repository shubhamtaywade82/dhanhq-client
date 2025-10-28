# frozen_string_literal: true

require_relative "../contracts/instrument_list_contract"

module DhanHQ
  module Models
    # Model wrapper for fetching instruments by exchange segment.
    class Instrument < BaseModel
      attributes :security_id, :symbol_name, :display_name, :exchange, :segment, :exchange_segment, :instrument, :series,
                 :lot_size, :tick_size, :expiry_date, :strike_price, :option_type, :underlying_symbol,
                 :isin, :instrument_type, :expiry_flag, :bracket_flag, :cover_flag, :asm_gsm_flag,
                 :asm_gsm_category, :buy_sell_indicator, :buy_co_min_margin_per, :sell_co_min_margin_per,
                 :mtf_leverage

      class << self
        # @return [DhanHQ::Resources::Instruments]
        def resource
          @resource ||= DhanHQ::Resources::Instruments.new
        end

        # Retrieve instruments for a given segment, returning an array of models.
        # @param exchange_segment [String]
        # @return [Array<Instrument>]
        def by_segment(exchange_segment)
          validate_params!({ exchange_segment: exchange_segment }, DhanHQ::Contracts::InstrumentListContract)

          csv_text = resource.by_segment(exchange_segment)
          return [] unless csv_text.is_a?(String) && !csv_text.empty?

          require "csv"
          rows = CSV.parse(csv_text, headers: true)
          rows.map { |r| new(normalize_csv_row(r), skip_validation: true) }
        end

        # Find a specific instrument by exchange segment and symbol.
        # @param exchange_segment [String] The exchange segment (e.g., "NSE_EQ", "IDX_I")
        # @param symbol [String] The symbol name to search for
        # @param options [Hash] Additional search options
        # @option options [Boolean] :exact_match Whether to perform exact symbol matching (default: false)
        # @option options [Boolean] :case_sensitive Whether the search should be case sensitive (default: false)
        # @return [Instrument, nil] The found instrument or nil if not found
        # @example
        #   # Find RELIANCE in NSE_EQ (uses underlying_symbol for equity)
        #   instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE")
        #   puts instrument.security_id  # => "2885"
        #
        #   # Find NIFTY in IDX_I (uses symbol_name for indices)
        #   instrument = DhanHQ::Models::Instrument.find("IDX_I", "NIFTY")
        #   puts instrument.security_id  # => "13"
        #
        #   # Exact match search
        #   instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "RELIANCE", exact_match: true)
        #
        #   # Case sensitive search
        #   instrument = DhanHQ::Models::Instrument.find("NSE_EQ", "reliance", case_sensitive: true)
        def find(exchange_segment, symbol, options = { exact_match: true, case_sensitive: false })
          validate_params!({ exchange_segment: exchange_segment, symbol: symbol }, DhanHQ::Contracts::InstrumentListContract)

          exact_match = options[:exact_match] || false
          case_sensitive = options[:case_sensitive] || false

          instruments = by_segment(exchange_segment)
          return nil if instruments.empty?

          search_symbol = case_sensitive ? symbol : symbol.upcase

          instruments.find do |instrument|
            # For equity instruments, prefer underlying_symbol over symbol_name
            instrument_symbol = if instrument.instrument == "EQUITY" && instrument.underlying_symbol
                                  case_sensitive ? instrument.underlying_symbol : instrument.underlying_symbol.upcase
                                else
                                  case_sensitive ? instrument.symbol_name : instrument.symbol_name.upcase
                                end

            if exact_match
              instrument_symbol == search_symbol
            else
              instrument_symbol.include?(search_symbol)
            end
          end
        end

        # Find a specific instrument across all exchange segments.
        # @param symbol [String] The symbol name to search for
        # @param options [Hash] Additional search options
        # @option options [Boolean] :exact_match Whether to perform exact symbol matching (default: false)
        # @option options [Boolean] :case_sensitive Whether the search should be case sensitive (default: false)
        # @option options [Array<String>] :segments Specific segments to search in (default: all common segments)
        # @return [Instrument, nil] The found instrument or nil if not found
        # @example
        #   # Find RELIANCE across all segments
        #   instrument = DhanHQ::Models::Instrument.find_anywhere("RELIANCE")
        #   puts "#{instrument.exchange_segment}:#{instrument.security_id}"  # => "NSE_EQ:2885"
        #
        #   # Find NIFTY across all segments
        #   instrument = DhanHQ::Models::Instrument.find_anywhere("NIFTY")
        #   puts "#{instrument.exchange_segment}:#{instrument.security_id}"  # => "IDX_I:13"
        #
        #   # Search only in specific segments
        #   instrument = DhanHQ::Models::Instrument.find_anywhere("RELIANCE", segments: ["NSE_EQ", "BSE_EQ"])
        def find_anywhere(symbol, options = {})
          exact_match = options[:exact_match] || false
          case_sensitive = options[:case_sensitive] || false
          segments = options[:segments] || %w[NSE_EQ BSE_EQ IDX_I NSE_FNO NSE_CURRENCY]

          segments.each do |segment|
            instrument = find(segment, symbol, exact_match: exact_match, case_sensitive: case_sensitive)
            return instrument if instrument
          end

          nil
        end

        def normalize_csv_row(row)
          # Extract exchange and segment from CSV
          exchange_id = row["EXCH_ID"] || row["EXCHANGE"]
          segment_code = row["SEGMENT"]

          # Calculate exchange_segment using SEGMENT_MAP from Constants
          exchange_segment = if exchange_id && segment_code
                               DhanHQ::Constants::SEGMENT_MAP[[exchange_id, segment_code]]
                             else
                               row["EXCH_ID"] # Fallback to original value
                             end

          {
            security_id: row["SECURITY_ID"].to_s,
            symbol_name: row["SYMBOL_NAME"],
            display_name: row["DISPLAY_NAME"],
            exchange: exchange_id,
            segment: segment_code,
            exchange_segment: exchange_segment,
            instrument: row["INSTRUMENT"],
            series: row["SERIES"],
            lot_size: row["LOT_SIZE"]&.to_f,
            tick_size: row["TICK_SIZE"]&.to_f,
            expiry_date: row["SM_EXPIRY_DATE"],
            strike_price: row["STRIKE_PRICE"]&.to_f,
            option_type: row["OPTION_TYPE"],
            underlying_symbol: row["UNDERLYING_SYMBOL"],
            isin: row["ISIN"],
            instrument_type: row["INSTRUMENT_TYPE"],
            expiry_flag: row["EXPIRY_FLAG"],
            bracket_flag: row["BRACKET_FLAG"],
            cover_flag: row["COVER_FLAG"],
            asm_gsm_flag: row["ASM_GSM_FLAG"],
            asm_gsm_category: row["ASM_GSM_CATEGORY"],
            buy_sell_indicator: row["BUY_SELL_INDICATOR"],
            buy_co_min_margin_per: row["BUY_CO_MIN_MARGIN_PER"]&.to_f,
            sell_co_min_margin_per: row["SELL_CO_MIN_MARGIN_PER"]&.to_f,
            mtf_leverage: row["MTF_LEVERAGE"]&.to_f
          }
        end
      end

      private

      def validation_contract
        nil
      end
    end
  end
end
