# frozen_string_literal: true

module DhanHQ
  module Resources
    class MarketFeed < BaseAPI
      HTTP_PATH = "/marketfeed"

      def ltp(params)
        post("/ltp", params: params)
      end

      def ohlc(params)
        post("/ohlc", params: params)
      end

      def quote(params)
        post("/quote", params: params)
      end
    end
  end
end
