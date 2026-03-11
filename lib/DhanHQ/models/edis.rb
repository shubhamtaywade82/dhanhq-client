# frozen_string_literal: true

require_relative "../contracts/edis_contract"

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
    #     segment: "EQ",
    #     bulk: false
    #   )
    #
    # @example Check EDIS status for a security (or "ALL" for all holdings)
    #   status = DhanHQ::Models::Edis.inquire(isin: "INE155A01022")
    #
    class Edis < BaseModel
      HTTP_PATH = "/v2/edis"

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
        # @param isin [String] ISIN of the security (e.g. "INE733E01010")
        # @param qty [Integer] Quantity to authorize for sale
        # @param exchange [String] Exchange: "NSE" or "BSE"
        # @param segment [String] Segment: "EQ", "COMM", or "FNO"
        # @param bulk [Boolean] If true, mark eDIS for all stocks in portfolio (default: false)
        #
        # @return [Hash] API response with dhanClientId and edisFormHtml (escaped HTML to render)
        #
        # @example Authorize sale of 10 shares
        #   DhanHQ::Models::Edis.generate_form(
        #     isin: "INE155A01022",
        #     qty: 10,
        #     exchange: "NSE",
        #     segment: "EQ"
        #   )
        #
        def generate_form(isin:, qty:, exchange:, segment:, bulk: false)
          params = { isin: isin, qty: qty, exchange: exchange, segment: segment, bulk: bulk }
          validate_params!(params, DhanHQ::Contracts::EdisFormContract)
          resource.form(params)
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
        # @param isin [String] ISIN of the security, or "ALL" for all holdings
        #
        # @return [Hash] API response with clientId, isin, totalQty, aprvdQty, status, remarks
        #
        # @example Check if EDIS is authorized for one security
        #   status = DhanHQ::Models::Edis.inquire(isin: "INE155A01022")
        #
        # @example Check EDIS status for all holdings
        #   status = DhanHQ::Models::Edis.inquire(isin: "ALL")
        #
        def inquire(isin:)
          resource.inquire(isin)
        end
      end
    end
  end
end
