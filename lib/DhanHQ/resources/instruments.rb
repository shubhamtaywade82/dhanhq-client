# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource client for fetching segment-wise instrument lists.
    class Instruments < BaseAPI
      # Instruments are served via the non-trading/data tier
      API_TYPE = :data_api
      # Base path for instruments endpoint
      HTTP_PATH = "/v2/instrument"

      # Fetch instruments for a given exchange segment.
      # Returns CSV text; the client parses to Array<Hash> upstream if needed.
      #
      # @param exchange_segment [String] e.g. "NSE_EQ", "NSE_FNO", "IDX_I"
      # @return [String] CSV content
      # @raise [DhanHQ::Error] When the API answers with an HTTP error.
      def by_segment(exchange_segment)
        path = "#{HTTP_PATH}/#{exchange_segment}"
        resp = client.connection.get(path)
        if resp.status.between?(300, 399) && resp.headers["location"]
          redirect_url = resp.headers["location"]
          Faraday.get(redirect_url).body
        else
          raise_for_failure!(resp) if resp.status >= 400

          resp.body
        end
      end

      private

      # Raises the error class mapped to the response status, so this non-JSON
      # endpoint fails like every other resource instead of handing the caller a
      # raw error body dressed up as CSV.
      #
      # @param resp [Faraday::Response]
      # @raise [DhanHQ::Error]
      def raise_for_failure!(resp)
        body = parse_error_body(resp.body)
        message = "#{body[:errorCode] || resp.status}: #{body[:errorMessage] || "Unknown error"}"
        klass = DhanHQ::ResponseHelper::STATUS_ERROR_FALLBACK.fetch(resp.status) do
          resp.status.between?(500, 599) ? DhanHQ::InternalServerError : DhanHQ::OtherError
        end
        raise klass, message
      end

      # Best-effort parse of a JSON error body; non-JSON bodies degrade to the raw text.
      #
      # @param raw [String]
      # @return [Hash]
      def parse_error_body(raw)
        JSON.parse(raw.to_s, symbolize_names: true)
      rescue JSON::ParserError
        {}
      end
    end
  end
end
