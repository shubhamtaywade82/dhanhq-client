# frozen_string_literal: true

module DhanHQ
  module Models
    module GlobalStocks
      ##
      # A single Global Stocks (US equity) holding.
      #
      # Unlike domestic holdings, US holdings report live valuation directly
      # (+ltp+, +current_value+, +gain_value+), so no quote lookup is needed to
      # compute unrealised P&L.
      #
      # @example Portfolio with unrealised P&L
      #   holdings = DhanHQ::Models::GlobalStocks::Holding.all
      #   holdings.each do |h|
      #     puts "#{h.trading_symbol}: #{h.quantity} @ $#{h.avg_cost_price} (#{h.gain_percentage}%)"
      #   end
      #   puts "Total: $#{DhanHQ::Models::GlobalStocks::Holding.total_current_value}"
      #
      class Holding < BaseModel
        HTTP_PATH = "/v2/globalstocks/holdings"

        attributes :dhan_client_id, :trading_symbol, :display_name, :security_id,
                   :exchange, :quantity, :avg_cost_price, :cost_value, :current_value,
                   :gain_value, :ltp, :prev_close, :long_term_flag, :last_updated

        # Returns a concise prompt-friendly summary of the holding.
        def to_prompt
          parts = ["#{quantity}x #{trading_symbol || security_id}"]
          parts << "avg_cost=$#{avg_cost_price}" if avg_cost_price&.positive?
          parts << "ltp=$#{ltp}" if ltp&.positive?
          parts << "value=$#{current_value}" if current_value
          parts << "pnl=$#{gain_value} (#{gain_percentage}%)" if gain_value
          parts.join(", ")
        end

        # Unrealised gain as a percentage of cost.
        #
        # @return [Float] 0.0 when cost value is unknown or zero.
        def gain_percentage
          cost = cost_value.to_f
          return 0.0 if cost.zero?

          (gain_value.to_f / cost * 100).round(2)
        end

        # @return [Boolean] True when the position is in profit.
        def profitable?
          gain_value.to_f.positive?
        end

        # @return [Boolean] True for a fractional-share position.
        def fractional?
          quantity.is_a?(Float) && (quantity % 1 != 0)
        end

        # Change against the previous close, per share.
        #
        # @return [Float, nil] nil when either price is unavailable.
        def day_change
          return nil unless ltp && prev_close

          (ltp.to_f - prev_close.to_f).round(4)
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::Holdings]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::Holdings.new
          end

          # Retrieves all Global Stocks holdings.
          #
          # @return [Array<Holding>] Empty array when there are no US holdings.
          def all
            response = resource.all
            return [] unless response.is_a?(Array)

            response.map { |holding| new(holding, skip_validation: true) }
          rescue DhanHQ::NoHoldingsError
            []
          end

          # Total market value of the US portfolio.
          #
          # @return [Float]
          def total_current_value
            all.sum { |holding| holding.current_value.to_f }
          end

          # Total unrealised P&L across the US portfolio.
          #
          # @return [Float]
          def total_gain
            all.sum { |holding| holding.gain_value.to_f }
          end
        end
      end
    end
  end
end
