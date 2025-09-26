# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for electronic DIS flows.
    class Edis < BaseAPI
      # EDIS endpoints are served from the trading API.
      API_TYPE = :order_api
      # Base path for EDIS endpoints.
      HTTP_PATH = "/v2/edis"

      # Creates a TPIN request form.
      #
      # @param params [Hash]
      # @return [Hash]
      def form(params)
        post("/form", params: params)
      end

      # Bulk EDIS form submission.
      #
      # @param params [Hash]
      # @return [Hash]
      def bulk_form(params)
        post("/bulkform", params: params)
      end

      # Generates a TPIN for the client.
      #
      # @return [Hash]
      def tpin
        get("/tpin")
      end

      # Checks the EDIS status for a given ISIN.
      #
      # @param isin [String]
      # @return [Hash]
      def inquire(isin)
        get("/inquire/#{isin}")
      end
    end
  end
end
