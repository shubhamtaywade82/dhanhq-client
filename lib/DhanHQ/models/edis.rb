# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model for EDIS (Electronic Delivery Instruction Slip) operations.
    #
    # EDIS is used for selling holdings from your demat account. The API provides
    # endpoints to generate T-PIN, create eDIS forms, and check authorization status.
    #
    # @example Generate T-PIN
    #   DhanHQ::Models::Edis.generate_tpin
    #
    # @example Generate eDIS form
    #   response = DhanHQ::Models::Edis.generate_form(
    #     isin: "INE155A01022",
    #     qty: 10,
    #     exchange: "NSE",
    #     segment: "E",
    #     bulk: false
    #   )
    #
    # @example Check EDIS status for a security
    #   status = DhanHQ::Models::Edis.inquire(isin: "INE155A01022")
    #
    class Edis < BaseModel
      HTTP_PATH = "/edis"

      class << self
        ##
        # Provides a shared instance of the Edis resource.
        #
        # @return [DhanHQ::Resources::Edis] The Edis resource client instance
        def resource
          @resource ||= DhanHQ::Resources::Edis.new
        end

        ##
        # Generate T-PIN for eDIS authorization.
        #
        # Triggers T-PIN generation which is sent to the user's registered mobile/email.
        #
        # @return [Hash] API response
        #
        # @example Generate T-PIN before selling holdings
        #   DhanHQ::Models::Edis.generate_tpin
        #
        def generate_tpin
          resource.tpin
        end

        ##
        # Generate an eDIS form for authorizing sale of holdings.
        #
        # @param isin [String] ISIN of the security (e.g., "INE155A01022")
        # @param qty [Integer] Quantity to authorize for sale
        # @param exchange [String] Exchange name (e.g., "NSE", "BSE")
        # @param segment [String] Segment identifier (e.g., "E")
        # @param bulk [Boolean] Whether this is a bulk authorization (default: false)
        #
        # @return [Hash] API response containing the eDIS form data
        #
        # @example Authorize sale of 10 shares
        #   DhanHQ::Models::Edis.generate_form(
        #     isin: "INE155A01022",
        #     qty: 10,
        #     exchange: "NSE",
        #     segment: "E"
        #   )
        #
        def generate_form(isin:, qty:, exchange:, segment:, bulk: false)
          resource.form({ isin: isin, qty: qty, exchange: exchange, segment: segment, bulk: bulk })
        end

        ##
        # Generate a bulk eDIS form for multiple securities.
        #
        # @param params [Hash] Bulk form parameters
        # @return [Hash] API response
        #
        def generate_bulk_form(params)
          resource.bulk_form(params)
        end

        ##
        # Check EDIS authorization status for a security.
        #
        # @param isin [String] ISIN of the security to check
        #
        # @return [Hash] API response containing authorization status
        #
        # @example Check if EDIS is authorized
        #   status = DhanHQ::Models::Edis.inquire(isin: "INE155A01022")
        #
        def inquire(isin:)
          resource.inquire(isin)
        end
      end

      ##
      # No validation contract needed — EDIS operations are simple API calls.
      #
      # @return [nil]
      # @api private
      def validation_contract
        nil
      end
    end
  end
end
