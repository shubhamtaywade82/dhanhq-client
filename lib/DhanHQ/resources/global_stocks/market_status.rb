# frozen_string_literal: true

module DhanHQ
  module Resources
    module GlobalStocks
      # Resource client for the US market session status.
      #
      #   GET /v2/globalstocks/marketstatus
      class MarketStatus < BaseAPI
        API_TYPE = :non_trading_api
        HTTP_PATH = "/v2/globalstocks/marketstatus"

        # Retrieves the current US market status and session timings.
        #
        # @return [Hash] `{ status:, marketOpenTime:, marketCloseTime:, holidayFlag: }`
        def fetch
          get("")
        end
      end
    end
  end
end
