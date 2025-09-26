# frozen_string_literal: true

require "bigdecimal"

module Live
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
end
