# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource for EDIS per https://dhanhq.co/docs/v2/edis/
    # GET /edis/tpin (generate T-PIN, 202 Accepted), POST /edis/form (body: isin, qty, exchange, segment, bulk),
    # POST /edis/bulkform, GET /edis/inquire/{isin} (or "ALL").
    # Form response: dhanClientId, edisFormHtml. Inquire response: clientId, isin, totalQty, aprvdQty, status, remarks.
    class Edis < BaseAPI
      API_TYPE  = :order_api
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
