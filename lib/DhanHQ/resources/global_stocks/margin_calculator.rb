# frozen_string_literal: true

module DhanHQ
  module Resources
    module GlobalStocks
      # Resource client for the Global Stocks pre-trade calculators.
      #
      #   POST /v2/globalstocks/margincalculator  — margin required for an order
      #   POST /v2/globalstocks/transEstimate     — charges applicable to an order
      #
      # Both endpoints take the same request body. The API documents +price+ and
      # +quantity+ as strings, so numeric input is stringified before sending.
      class MarginCalculator < BaseAPI
        API_TYPE = :non_trading_api
        HTTP_PATH = "/v2/globalstocks"

        # Calculates the margin required for a Global Stocks order.
        #
        # @param params [Hash] `:security_id`, `:transaction_type`, `:price`, `:quantity`
        # @return [Hash] Margin breakdown.
        def calculate(params)
          post("/margincalculator", params: wire_params(params))
        end

        # Estimates the charges applicable to a Global Stocks order.
        #
        # @param params [Hash] `:security_id`, `:transaction_type`, `:price`, `:quantity`
        # @return [Hash] Charge breakdown.
        def estimate(params)
          post("/transEstimate", params: wire_params(params))
        end

        private

        # Validates against the shared estimator contract, then renders the numeric
        # fields as strings the way the API expects them.
        def wire_params(params)
          validated = validate!(params)
          validated.merge(
            price: format_number(validated[:price]),
            quantity: format_number(validated[:quantity])
          )
        end

        # Fields the API documents as strings but which are validated as numbers.
        NUMERIC_KEYS = %i[price quantity].freeze
        private_constant :NUMERIC_KEYS

        def validate!(params)
          attrs = snake_case(params).each_with_object({}) do |(key, value), out|
            out[key] = NUMERIC_KEYS.include?(key) ? Float(value) : value
          end
          result = Contracts::GlobalStocksEstimatorContract.new.call(attrs)
          raise DhanHQ::ValidationError, "Invalid parameters: #{result.errors.to_h}" unless result.success?

          result.to_h
        rescue ArgumentError, TypeError => e
          raise DhanHQ::ValidationError, "Invalid parameters: price and quantity must be numeric (#{e.message})"
        end

        # Renders 180.0 as "180" and 1.5 as "1.5" so the payload matches the
        # documented examples rather than leaking Ruby float formatting.
        def format_number(value)
          float = Float(value)
          float == float.to_i ? float.to_i.to_s : float.to_s
        end
      end
    end
  end
end
