# frozen_string_literal: true

module DhanHQ
  module Resources
    ##
    # Resource for the ScanX data API endpoints (POST /v2/data/*).
    #
    # Covers company fundamentals, market movers, live news headlines and
    # server-side technical indicators. These are market-data endpoints, so in
    # hybrid mode they keep hitting the production host.
    class ScanX < BaseAPI
      # ScanX requests hit the data API tier (5 req/sec, 7,000/day).
      API_TYPE = :data_api
      # Root path for the ScanX data endpoints.
      HTTP_PATH = "/v2/data"

      ##
      # POST /v2/data/companyinfo
      # Company overview, valuation/profitability ratios and shareholding
      # pattern for a single equity instrument.
      #
      # @param params [Hash] Example:
      #   {
      #     security_id: "1333",
      #     exchange_segment: "NSE_EQ",
      #     instrument: "EQUITY",
      #     metrics: ["CO", "RATIOS", "SHP"]
      #   }
      # @return [HashWithIndifferentAccess]
      def company_info(params)
        validate_with!(Contracts::CompanyInfoContract, params)
        post("/companyinfo", params: params)
      end

      ##
      # POST /v2/data/marketmovers
      # Top options, futures and stocks ranked by open interest, volume or
      # price movement.
      #
      # @param params [Hash] Example:
      #   {
      #     exchange_segment: "NSE_FNO",
      #     instrument: ["OPTIDX", "OPTSTK"],
      #     category: "HIGHEST_OI",
      #     expiry: "2026-10-29",
      #     limit: 10
      #   }
      #   For EQUITY rankings pass +universe:+ (e.g. "NIFTY_50") instead of expiry.
      # @return [HashWithIndifferentAccess]
      def market_movers(params)
        validate_with!(Contracts::MarketMoversContract, params)
        post("/marketmovers", params: params)
      end

      ##
      # POST /v2/data/newsheadline
      # Latest news headlines, filterable by category and stock (max 50 items).
      # +dhanClientId+ is injected automatically from the configuration.
      #
      # @param params [Hash] Example:
      #   { categories: ["ALL"], limit: 10, stock_list: ["1333"] }
      # @return [HashWithIndifferentAccess]
      def news_headlines(params)
        validate_with!(Contracts::NewsHeadlineContract, params)
        post("/newsheadline", params: params)
      end

      ##
      # POST /v2/data/technical
      # Server-side technical indicator values for an instrument. Only the
      # requested indicators are computed and returned.
      #
      # @param params [Hash] Example:
      #   {
      #     security_id: "1333",
      #     exchange_segment: "NSE_EQ",
      #     instrument: "EQUITY",
      #     timeframe: "D",
      #     indicators: ["SMA_20", "RSI_14", "MACD_HIST"]
      #   }
      # @return [HashWithIndifferentAccess]
      def technical_data(params)
        validate_with!(Contracts::TechnicalDataContract, params)
        post("/technical", params: params)
      end

      private

      # Runs the given contract and raises DhanHQ::ValidationError on failure.
      def validate_with!(contract_class, params)
        result = contract_class.new.call(snake_case(params))
        return if result.success?

        raise DhanHQ::ValidationError, "Invalid parameters: #{result.errors.to_h}"
      end
    end
  end
end
