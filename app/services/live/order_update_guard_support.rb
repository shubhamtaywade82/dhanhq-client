# frozen_string_literal: true

module Live
  # Guard-related helpers for interpreting order update payloads.
  module OrderUpdateGuardSupport
    module_function

    SEGMENT_MAP = {
      %w[NSE E] => "NSE_EQ",
      %w[BSE E] => "BSE_EQ",
      %w[NSE D] => "NSE_FNO",
      %w[BSE D] => "BSE_FNO",
      %w[NSE C] => "NSE_CURRENCY",
      %w[BSE C] => "BSE_CURRENCY",
      %w[MCX M] => "MCX_COMM"
    }.freeze

    DEFAULT_SL_VALUE    = 15.0
    DEFAULT_TP_VALUE    = 30.0
    DEFAULT_TRAIL_VALUE = 5.0

    def map_segment(exchange, segment)
      key = [exchange.to_s.upcase, segment.to_s.upcase]
      SEGMENT_MAP.fetch(key, "NSE_EQ")
    end

    def position_guard_payload(segment, security_id, order_data)
      guard_base_payload(segment, security_id, order_data)
        .merge(guard_price_payload(segment, security_id))
    end

    def guard_base_payload(segment, security_id, order_data)
      {
        pos_id: nil,
        exchange_segment: segment,
        security_id: security_id,
        entry: average_entry(order_data),
        qty: order_data[:TradedQty].to_i,
        placed_as: placed_as(order_data),
        super_order_id: order_data[:OrderNo].to_s
      }
    end

    def guard_price_payload(segment, security_id)
      {
        sl_value: default_sl_value(segment, security_id),
        tp_value: default_tp_value(segment, security_id),
        trail_value: default_trail_value(segment, security_id)
      }
    end

    def placed_as(order_data)
      order_data[:Remarks].to_s.match?(/Super Order/i) ? "super" : "plain"
    end

    def average_entry(order_data)
      first_price = [order_data[:AvgTradedPrice], order_data[:TradedPrice], order_data[:Price]]
                    .compact
                    .first
      first_price.to_f
    end

    def default_sl_value(_segment, _security_id)
      DEFAULT_SL_VALUE
    end

    def default_tp_value(_segment, _security_id)
      DEFAULT_TP_VALUE
    end

    def default_trail_value(_segment, _security_id)
      DEFAULT_TRAIL_VALUE
    end
  end
end
