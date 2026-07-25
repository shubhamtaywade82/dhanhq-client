# frozen_string_literal: true

module DhanHQ
  module Models
    module GlobalStocks
      ##
      # Charge estimate for a prospective Global Stocks order.
      #
      # @example Estimate the cost of a trade before placing it
      #   est = DhanHQ::Models::GlobalStocks::OrderEstimate.calculate(
      #     security_id: "AAPL", transaction_type: "BUY", price: 180.0, quantity: 1
      #   )
      #   puts "Charges: $#{est.total_charges}"
      #
      class OrderEstimate < BaseModel
        HTTP_PATH = "/v2/globalstocks/transEstimate"

        attributes :brokerage, :order_charges, :exchange_charges, :turn_over_fee,
                   :gst_charges, :other_charges

        # Returns a concise prompt-friendly summary of the charges.
        def to_prompt
          parts = []
          parts << "brokerage=$#{brokerage}" if brokerage
          parts << "exchange=$#{exchange_charges}" if exchange_charges
          parts << "gst=$#{gst_charges}" if gst_charges
          parts << "total=$#{total_charges}"
          parts.join(", ")
        end

        # Sum of every charge component.
        #
        # The API also returns +order_charges+ as its own total; this method adds up
        # the components so the figure stays correct even when the API omits it.
        #
        # @return [Float]
        def total_charges
          [brokerage, exchange_charges, turn_over_fee, gst_charges, other_charges]
            .sum(&:to_f)
            .round(4)
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::MarginCalculator]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::MarginCalculator.new
          end

          # Estimates the charges applicable to a Global Stocks order.
          #
          # @param params [Hash] `:security_id`, `:transaction_type`, `:price`, `:quantity`
          # @return [OrderEstimate]
          def calculate(params)
            new(resource.estimate(params), skip_validation: true)
          end
          alias estimate calculate
        end
      end
    end
  end
end
