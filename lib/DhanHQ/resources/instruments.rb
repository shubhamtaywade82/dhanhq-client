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
      def by_segment(exchange_segment)
        path = "#{HTTP_PATH}/#{exchange_segment}"
        resp = client.connection.get(path)
        if resp.status.between?(300, 399) && resp.headers["location"]
          redirect_url = resp.headers["location"]
          return Faraday.get(redirect_url).body
        end
        resp.body
      end
    end
  end
end
