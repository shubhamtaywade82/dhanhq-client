# frozen_string_literal: true

require_relative "../contracts/instrument_list_contract"

module DhanHQ
  module Models
    # Model wrapper for fetching instruments by exchange segment.
    class Instrument < BaseModel
      attributes :security_id, :symbol_name, :display_name, :exchange_segment, :instrument, :series,
                 :lot_size, :tick_size, :expiry_date, :strike_price, :option_type

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

        def normalize_csv_row(row)
          {
            security_id: row["SECURITY_ID"].to_s,
            symbol_name: row["SYMBOL_NAME"],
            display_name: row["DISPLAY_NAME"],
            exchange_segment: row["EXCH_ID"],
            instrument: row["INSTRUMENT"],
            series: row["SERIES"],
            lot_size: row["LOT_SIZE"]&.to_f,
            tick_size: row["TICK_SIZE"]&.to_f,
            expiry_date: row["SM_EXPIRY_DATE"],
            strike_price: row["STRIKE_PRICE"]&.to_f,
            option_type: row["OPTION_TYPE"]
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
