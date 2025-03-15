# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model class for fetching Daily & Intraday data
    # The default response is a Hash with arrays of "open", "high", "low", etc.
    #
    class HistoricalData < BaseModel
      # Typically, we won't define a single resource path,
      # because we call "daily" or "intraday" endpoints specifically.
      # So let's rely on the resource call directly.
      HTTP_PATH = "/v2/charts"

      # If you want typed attributes, you could define them,
      # but the endpoints return arrays. We'll keep it raw.
      # e.g. attributes :open, :high, :low, :close, :volume, :timestamp

      class << self
        ##
        # Provide a **shared instance** of the `HistoricalData` resource
        #
        # @return [DhanHQ::Resources::HistoricalData]
        def resource
          @resource ||= DhanHQ::Resources::HistoricalData.new
        end

        ##
        # Daily historical data
        # @param params [Hash] The request parameters, e.g.:
        #   {
        #     security_id: "1333",
        #     exchange_segment: "NSE_EQ",
        #     instrument: "EQUITY",
        #     expiry_code: 0,
        #     from_date: "2022-01-08",
        #     to_date: "2022-02-08"
        #   }
        # @return [HashWithIndifferentAccess]
        #   {
        #     open: [...], high: [...], low: [...], close: [...],
        #     volume: [...], timestamp: [...]
        #   }
        def daily(params)
          validate_params!(params, DhanHQ::Contracts::HistoricalDataContract)
          # You can rename the keys from snake_case to something if needed
          resource.daily(params)
          # return as a raw hash or transform further
        end

        ##
        # Intraday historical data
        # @param params [Hash], e.g.:
        #   {
        #     security_id: "1333",
        #     exchange_segment: "NSE_EQ",
        #     instrument: "EQUITY",
        #     interval: "15",
        #     from_date: "2024-09-11",
        #     to_date: "2024-09-15"
        #   }
        # @return [HashWithIndifferentAccess]
        #   { open: [...], high: [...], low: [...], close: [...],
        #     volume: [...], timestamp: [...] }
        def intraday(params)
          validate_params!(params, DhanHQ::Contracts::HistoricalDataContract)
          resource.intraday(params)
        end
      end

      # For a read-only type of data, we might skip validations or specify a contract if needed
      def validation_contract
        nil
      end
    end
  end
end
