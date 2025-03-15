# frozen_string_literal: true

module DhanHQ
  module Models
    class Position < BaseModel
      HTTP_PATH = "/v2/positions"

      attributes :dhan_client_id, :trading_symbol, :security_id, :position_type, :exchange_segment,
                 :product_type, :buy_avg, :buy_qty, :cost_price, :sell_avg, :sell_qty,
                 :net_qty, :realized_profit, :unrealized_profit, :rbi_reference_rate, :multiplier,
                 :carry_forward_buy_qty, :carry_forward_sell_qty, :carry_forward_buy_value,
                 :carry_forward_sell_value, :day_buy_qty, :day_sell_qty, :day_buy_value,
                 :day_sell_value, :drv_expiry_date, :drv_option_type, :drv_strike_price,
                 :cross_currency

      class << self
        ##
        # Provides a **shared instance** of the `Positions` resource.
        #
        # @return [DhanHQ::Resources::Positions]
        def resource
          @resource ||= DhanHQ::Resources::Positions.new
        end

        ##
        # Fetch all positions for the day.
        #
        # @return [Array<Position>]
        def all
          response = resource.all
          return [] unless response.is_a?(Array)

          response.map do |position|
            new(snake_case(position), skip_validation: true)
          end
        end

        def active
          all.reject { |position| position.position_type == "CLOSED" }
        end
      end
    end
  end
end
