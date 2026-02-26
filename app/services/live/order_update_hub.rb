# frozen_string_literal: true

require "singleton"
require_relative "order_update_guard_support"
require_relative "order_update_persistence_support"

module Live
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
        order_data[:Status].to_s.upcase == DhanHQ::Constants::OrderStatus::TRADED &&
        order_data[:TradedQty].to_i.positive?
    end
  end
end
