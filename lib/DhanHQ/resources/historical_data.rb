# frozen_string_literal: true

module DhanHQ
  module Resources
    class HistoricalData < BaseAPI
      HTTP_PATH = "/charts"

      def daily(params)
        post("/historical", params: params)
      end

      def intraday(params)
        post("/intraday", params: params)
      end
    end
  end
end
