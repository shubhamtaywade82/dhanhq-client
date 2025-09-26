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

    DEFAULT_SL_PCT    = 0.15
    DEFAULT_TP_PCT    = 0.30
    DEFAULT_TRAIL_PCT = 0.01

    def map_segment(exchange, segment)
      key = [exchange.to_s.upcase, segment.to_s.upcase]
      SEGMENT_MAP.fetch(key, "NSE_EQ")
    end

    def position_guard_payload(segment, security_id, order_data)
      guard_base_payload(segment, security_id, order_data)
        .merge(guard_percentage_payload(segment, security_id))
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

    def guard_percentage_payload(segment, security_id)
      {
        sl_pct: default_sl_pct(segment, security_id),
        tp_pct: default_tp_pct(segment, security_id),
        trail_pct: default_trail_pct(segment, security_id)
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

    def default_sl_pct(_segment, _security_id)
      DEFAULT_SL_PCT
    end

    def default_tp_pct(_segment, _security_id)
      DEFAULT_TP_PCT
    end

    def default_trail_pct(_segment, _security_id)
      DEFAULT_TRAIL_PCT
    end
  end
end
