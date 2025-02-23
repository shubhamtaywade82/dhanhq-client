# frozen_string_literal: true

module DhanHQ
  module Models
    class Holding < BaseModel
      HTTP_PATH = "/v2/holdings"

      attributes :exchange, :trading_symbol, :security_id, :isin, :total_qty,
                 :dp_qty, :t1_qty, :available_qty, :collateral_qty, :avg_cost_price

      class << self
        ##
        # Provides a **shared instance** of the `Holdings` resource.
        #
        # @return [DhanHQ::Resources::Holdings]
        def resource
          @resource ||= DhanHQ::Resources::Holdings.new
        end

        ##
        # Fetch all holdings.
        #
        # @return [Array<Holding>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map { |holding| new(holding, skip_validation: true) }
        end
      end

      ##
      # Convert model attributes to a hash.
      #
      # @return [Hash] Hash representation of the Holding model.
      def to_h
        {
          exchange: exchange,
          trading_symbol: trading_symbol,
          security_id: security_id,
          isin: isin,
          total_qty: total_qty,
          dp_qty: dp_qty,
          t1_qty: t1_qty,
          available_qty: available_qty,
          collateral_qty: collateral_qty,
          avg_cost_price: avg_cost_price
        }
      end
    end
  end
end
