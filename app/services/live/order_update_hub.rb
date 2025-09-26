# frozen_string_literal: true
require "singleton"

module Live
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

    def handle(msg)
      return unless msg&.dig(:Type) == "order_alert"
      data = msg[:Data] || {}

      # 1) Persist/update a local Order row (adapt field names to your model)
      upsert_local_order(data)

      # 2) Event hooks for execution flow:
      # Entry leg traded -> subscribe the option leg for exits and register to guard
      if entry_leg_traded?(data)
        seg = map_segment(data[:Exchange], data[:Segment])
        sid = data[:SecurityId].to_s
        Live::WsHub.instance.subscribe(seg: seg, sid: sid) if defined?(Live::WsHub)

        # register/refresh PositionGuard for trailing
        if defined?(Execution::PositionGuard)
          qty = data[:TradedQty].to_i
          entry = (data[:AvgTradedPrice] || data[:TradedPrice] || data[:Price]).to_f
          Execution::PositionGuard.instance.register(
            pos_id: nil,
            exchange_segment: seg,
            security_id: sid,
            entry: entry,
            qty: qty,
            sl_pct: default_sl_pct(seg, sid),
            tp_pct: default_tp_pct(seg, sid),
            trail_pct: default_trail_pct(seg, sid),
            placed_as: (data[:Remarks].to_s =~ /Super Order/i ? "super" : "plain"),
            super_order_id: data[:OrderNo].to_s
          )
        end
      end

      # If stop/target leg executed, PositionGuard will receive ticks and exit,
      # but you can also reconcile here if needed.
    rescue => e
      Rails.logger.error("[OrderUpdateHub] #{e.class}: #{e.message}")
    end

    def upsert_local_order(d)
      # Example using a BrokerOrder model (adapt to your schema)
      # keys
      order_no = d[:OrderNo].to_s
      rec = BrokerOrder.find_or_initialize_by(order_no: order_no)
      rec.assign_attributes(
        exch_order_no:    d[:ExchOrderNo].to_s,
        status:           d[:Status],
        product:          d[:ProductName] || d[:Product],
        txn_type:         d[:TxnType],
        order_type:       d[:OrderType],
        validity:         d[:Validity],
        exchange:         d[:Exchange],
        segment:          d[:Segment],
        security_id:      d[:SecurityId].to_s,
        quantity:         d[:Quantity].to_i,
        traded_qty:       d[:TradedQty].to_i,
        price:            to_d(d[:Price]),
        trigger_price:    to_d(d[:TriggerPrice]),
        traded_price:     to_d(d[:TradedPrice]),
        avg_traded_price: to_d(d[:AvgTradedPrice]),
        last_update_at:   parse_ts(d[:LastUpdatedTime]),
        raw_payload:      d
      )
      rec.save!
    rescue NameError
      # If you don’t have a BrokerOrder model, skip. You can wire to PositionsImporter instead.
      nil
    end

    def entry_leg_traded?(d)
      d[:LegNo].to_i == 1 && d[:Status].to_s.upcase == "TRADED" && d[:TradedQty].to_i > 0
    end

    def map_segment(exchange, segment)
      # Exchange: "NSE"/"BSE"/"MCX", Segment: "E" (Equity), "D" (F&O) etc.
      case [exchange.to_s.upcase, segment.to_s.upcase]
      when ["NSE","E"] then "NSE_EQ"
      when ["BSE","E"] then "BSE_EQ"
      when ["NSE","D"] then "NSE_FNO"
      when ["BSE","D"] then "BSE_FNO"
      when ["NSE","C"] then "NSE_CURRENCY"
      when ["BSE","C"] then "BSE_CURRENCY"
      when ["MCX","M"] then "MCX_COMM"
      else "NSE_EQ"
      end
    end

    def default_sl_pct(_seg, _sid) = 0.15  # 15% option SL (tune/override per symbol)
    def default_tp_pct(_seg, _sid) = 0.30  # 30% target
    def default_trail_pct(_seg, _sid) = 0.01  # 1% trail step

    def to_d(x) = x.nil? ? 0.to_d : x.to_d
    def parse_ts(s)
      return nil if s.nil? || s == ""
      Time.zone.parse(s) rescue nil
    end
  end
end
