# frozen_string_literal: true

module DhanHQ
  module Models
    module GlobalStocks
      ##
      # Margin requirement for a prospective Global Stocks order.
      #
      # @example Check affordability before placing
      #   margin = DhanHQ::Models::GlobalStocks::Margin.calculate(
      #     security_id: "AAPL", transaction_type: "BUY", price: 180.0, quantity: 10
      #   )
      #   puts "Need $#{margin.total_margin}, have $#{margin.available_bal}"
      #   raise "Insufficient funds" unless margin.sufficient?
      #
      class Margin < BaseModel
        HTTP_PATH = "/v2/globalstocks/margincalculator"

        attributes :insufficient_bal, :brokerage, :leverage, :total_margin, :available_bal

        # Returns a concise prompt-friendly summary of the margin requirement.
        def to_prompt
          parts = []
          parts << "total_margin=$#{total_margin}" if total_margin
          parts << "available=$#{available_bal}" if available_bal
          parts << "brokerage=$#{brokerage}" if brokerage
          parts << "leverage=#{leverage}" if leverage
          parts << "shortfall=$#{insufficient_bal}" if insufficient_bal.to_f.positive?
          parts.join(", ")
        end

        # @return [Boolean] True when the account can fund the order.
        def sufficient?
          !insufficient_bal.to_f.positive?
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::MarginCalculator]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::MarginCalculator.new
          end

          # Calculates the margin required for a Global Stocks order.
          #
          # @param params [Hash] `:security_id`, `:transaction_type`, `:price`, `:quantity`
          # @return [Margin]
          def calculate(params)
            new(resource.calculate(params), skip_validation: true)
          end
        end
      end
    end
  end
end
