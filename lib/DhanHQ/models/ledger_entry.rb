# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Represents a single row/entry in the Ledger.
    # Ledger data typically returns an array of these objects.
    class LedgerEntry < BaseModel
      # The endpoint is /v2/ledger?from-date=...&to-date=...
      # So we may define a resource path or rely on the Statements resource.
      HTTP_PATH = "/v2/ledger"

      # Typical fields from API docs
      attributes :dhan_client_id, :narration, :voucherdate, :exchange,
                 :voucherdesc, :vouchernumber, :debit, :credit, :runbal

      class << self
        ##
        # Provides a **shared instance** of the `Statements` resource.
        #
        # @return [DhanHQ::Resources::Statements]
        def resource
          @resource ||= DhanHQ::Resources::Statements.new
        end

        ##
        # Fetch ledger entries for the given date range.
        #
        # @param from_date [String] e.g. "2023-01-01"
        # @param to_date   [String] e.g. "2023-01-31"
        # @return [Array<LedgerEntry>]
        def all(from_date:, to_date:)
          # The resource call returns an Array<Hash>, according to the docs.
          response = resource.ledger(from_date: from_date, to_date: to_date)

          return [] unless response.is_a?(Array)

          response.map do |entry|
            new(entry, skip_validation: true)
          end
        end
      end

      # Optional: you can override #to_h or #inspect if you want a custom representation
      def to_h
        {
          dhan_client_id: dhan_client_id,
          narration: narration,
          voucherdate: voucherdate,
          exchange: exchange,
          voucherdesc: voucherdesc,
          vouchernumber: vouchernumber,
          debit: debit,
          credit: credit,
          runbal: runbal
        }
      end
    end
  end
end
