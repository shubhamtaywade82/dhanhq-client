# frozen_string_literal: true

module DhanHQ
  module Resources
    class Edis < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/edis"

      def form(params)
        post("/form", params: params)
      end

      def bulk_form(params)
        post("/bulkform", params: params)
      end

      def tpin
        get("/tpin")
      end

      def inquire(isin)
        get("/inquire/#{isin}")
      end
    end
  end
end
