# frozen_string_literal: true

module DhanHQ
  module Resources
    ##
    # Provides methods to retrieve Ledger and Trade History.
    #
    # GET /v2/ledger?from-date=YYYY-MM-DD&to-date=YYYY-MM-DD
    # GET /v2/trades/{from-date}/{to-date}/{page}
    #
    class Statements < BaseAPI
      # Statement history is fetched from the non-trading API tier.
      API_TYPE = :non_trading_api
      # Base path for ledger and trade history.
      HTTP_PATH = "/v2"

      ##
      # GET /v2/ledger?from-date=YYYY-MM-DD&to-date=YYYY-MM-DD
      # @param from_date [String] e.g. "2023-01-01"
      # @param to_date   [String] e.g. "2023-01-31"
      # @return [Array<Hash>] An array of ledger entries
      def ledger(from_date:, to_date:)
        # Because the docs say "from-date" & "to-date" (with dashes),
        # pass them as snake case or match them exactly:
        get("/ledger", params: { "from-date": from_date, "to-date": to_date })
      end

      ##
      # GET /v2/trades/{from-date}/{to-date}/{page}
      # @param from_date [String]
      # @param to_date   [String]
      # @param page      [Integer] Defaults to 0
      # @return [Array<Hash>] An array of trades
      #
      def trade_history(from_date:, to_date:, page: 0)
        # docs show this path style:
        # /v2/trades/{from-date}/{to-date}/{page}
        get("/trades/#{from_date}/#{to_date}/#{page}")
      end
    end
  end
end
