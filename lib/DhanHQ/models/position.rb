# frozen_string_literal: true

module DhanHQ
  module Models
    # Model representing an intraday or carry-forward position snapshot.
    class Position < BaseModel
      # Base path used by the positions resource.
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

        # Filters the position list down to non-closed entries.
        #
        # @return [Array<Position>]
        def active
          all.reject { |position| position.position_type == "CLOSED" }
        end

        # Convert an existing position (intraday <-> delivery)
        # @param params [Hash] parameters as required by the API
        # @return [Hash, DhanHQ::ErrorObject]
        def convert(params)
          formatted_params = camelize_keys(params)
          validate_params!(formatted_params, DhanHQ::Contracts::PositionConversionContract)

          response = resource.convert(formatted_params)
          success_response?(response) ? response : DhanHQ::ErrorObject.new(response)
        end
      end
    end
  end
end
