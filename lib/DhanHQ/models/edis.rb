# frozen_string_literal: true

module DhanHQ
  module Models
    # Model wrapper for electronic DIS flows.
    class Edis < BaseModel
      # Base path backing the model operations.
      HTTP_PATH = "/v2/edis"

      class << self
        # Shared resource client used by the model helpers.
        #
        # @return [DhanHQ::Resources::Edis]
        def resource
          @resource ||= DhanHQ::Resources::Edis.new
        end

        # Submits an EDIS form request.
        #
        # @param params [Hash]
        # @return [Hash]
        def form(params)
          resource.form(params)
        end

        # Submits a bulk EDIS form request.
        #
        # @param params [Hash]
        # @return [Hash]
        def bulk_form(params)
          resource.bulk_form(params)
        end

        # Requests a TPIN for the configured client.
        #
        # @return [Hash]
        def tpin
          resource.tpin
        end

        # Inquires EDIS status for a specific ISIN.
        #
        # @param isin [String]
        # @return [Hash]
        def inquire(isin)
          resource.inquire(isin)
        end
      end

      # EDIS payloads are validated upstream so no contract is applied.
      #
      # @return [nil]
      def validation_contract
        nil
      end
    end
  end
end
