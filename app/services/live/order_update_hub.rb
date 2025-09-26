# frozen_string_literal: true

require "bigdecimal"
require "singleton"

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

  # Persistence helper routines for order update payloads.
  module OrderUpdatePersistenceSupport
    module_function

    def local_order_attributes(order_data)
      identity_attributes(order_data)
        .merge(quantity_attributes(order_data))
        .merge(price_attributes(order_data))
        .merge(timestamp_attributes(order_data))
    end

    def identity_attributes(order_data)
      {
        exch_order_no: order_data[:ExchOrderNo].to_s,
        status: order_data[:Status],
        product: order_data[:ProductName] || order_data[:Product],
        txn_type: order_data[:TxnType],
        order_type: order_data[:OrderType]
      }
    end

    def quantity_attributes(order_data)
      {
        validity: order_data[:Validity],
        exchange: order_data[:Exchange],
        segment: order_data[:Segment],
        security_id: order_data[:SecurityId].to_s,
        quantity: order_data[:Quantity].to_i,
        traded_qty: order_data[:TradedQty].to_i
      }
    end

    def price_attributes(order_data)
      {
        price: decimal(order_data[:Price]),
        trigger_price: decimal(order_data[:TriggerPrice]),
        traded_price: decimal(order_data[:TradedPrice]),
        avg_traded_price: decimal(order_data[:AvgTradedPrice])
      }
    end

    def timestamp_attributes(order_data)
      {
        last_update_at: parse_timestamp(order_data[:LastUpdatedTime]),
        raw_payload: order_data
      }
    end

    def decimal(value)
      return BigDecimal(0) if value.nil?

      BigDecimal(value.to_s)
    end

    def parse_timestamp(timestamp)
      return nil if timestamp.nil? || timestamp == ""

      Time.zone.parse(timestamp)
    rescue StandardError
      nil
    end
  end

  # OrderUpdateHub listens for order updates over WebSocket and wires them into
  # local persistence plus downstream execution helpers.
  class OrderUpdateHub
    include Singleton

    def start!
      return self if @started

      @client = DhanHQ::WS::Orders::Client.new.start
      @client.on(:update) { |msg| handle(msg) }
      @started = true
      self
    end

    def stop!
      @client&.stop
      @started = false
    end

    private

    def handle(message)
      return unless order_alert?(message)

      order_data = message[:Data] || {}
      upsert_local_order(order_data)
      handle_entry_leg(order_data)
    rescue StandardError => e
      Rails.logger.error("[OrderUpdateHub] #{e.class}: #{e.message}")
    end

    def order_alert?(message)
      message&.dig(:Type) == "order_alert"
    end

    def handle_entry_leg(order_data)
      return unless entry_leg_traded?(order_data)

      segment = OrderUpdateGuardSupport.map_segment(order_data[:Exchange], order_data[:Segment])
      security_id = order_data[:SecurityId].to_s
      Live::WsHub.instance.subscribe(seg: segment, sid: security_id) if defined?(Live::WsHub)

      register_position_guard(segment, security_id, order_data)
    end

    def register_position_guard(segment, security_id, order_data)
      return unless defined?(Execution::PositionGuard)

      payload = OrderUpdateGuardSupport.position_guard_payload(segment, security_id, order_data)
      Execution::PositionGuard.instance.register(**payload)
    end

    def upsert_local_order(order_data)
      order_number = order_data[:OrderNo].to_s
      record = BrokerOrder.find_or_initialize_by(order_no: order_number)
      attributes = OrderUpdatePersistenceSupport.local_order_attributes(order_data)
      record.assign_attributes(attributes)
      record.save!
    rescue NameError
      nil
    end

    def entry_leg_traded?(order_data)
      order_data[:LegNo].to_i == 1 &&
        order_data[:Status].to_s.upcase == "TRADED" &&
        order_data[:TradedQty].to_i.positive?
    end
  end
end
