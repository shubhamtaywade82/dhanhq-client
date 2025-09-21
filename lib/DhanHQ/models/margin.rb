# frozen_string_literal: true

module DhanHQ
  module Models
    class Margin < BaseModel
      HTTP_PATH = "/v2/margincalculator"

      attr_reader :total_margin, :span_margin, :exposure_margin, :available_balance,
                  :variable_margin, :insufficient_balance, :brokerage, :leverage

      class << self
        ##
        # Provides a **shared instance** of the `MarginCalculator` resource.
        #
        # @return [DhanHQ::Resources::MarginCalculator]
        def resource
          @resource ||= DhanHQ::Resources::MarginCalculator.new
        end

        ##
        # Calculate margin requirements for an order.
        #
        # @param params [Hash] Request parameters for margin calculation.
        # @return [Margin]
        def calculate(params)
          formatted_params = camelize_keys(params)
          validate_params!(formatted_params, DhanHQ::Contracts::MarginCalculatorContract)

          response = resource.calculate(formatted_params)
          new(response, skip_validation: true)
        end
      end

      ##
      # Convert model attributes to a hash.
      #
      # @return [Hash] Hash representation of the Margin model.
      def to_h
        {
          total_margin: total_margin,
          span_margin: span_margin,
          exposure_margin: exposure_margin,
          available_balance: available_balance,
          variable_margin: variable_margin,
          insufficient_balance: insufficient_balance,
          brokerage: brokerage,
          leverage: leverage
        }
      end
    end
  end
end
