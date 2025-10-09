# frozen_string_literal: true

require_relative "helpers/bias_aggregator"
require_relative "helpers/moneyness_helper"
require_relative "../contracts/options_buying_advisor_contract"

module DhanHQ
  module Analysis
    class OptionsBuyingAdvisor
      DEFAULT_CONFIG = {
        timeframe_weights: { m1: 0.1, m5: 0.2, m15: 0.25, m25: 0.15, m60: 0.3 },
        min_adx_for_trend: 22,
        strong_adx: 35,
        min_oi: 10_000,
        max_spread_pct: 1.0,
        preferred_deltas: {
          ce: { otm: (0.35..0.45), atm: (0.48..0.52), itm: (0.55..0.70) },
          pe: { otm: (-0.45..-0.35), atm: (-0.52..-0.48), itm: (-0.70..-0.55) }
        },
        risk: { sl_pct: 0.30, tp_pct: 0.60, trail_arm_pct: 0.20, trail_step_pct: 0.10 },
        atr_to_rupees_factor: 1.0
      }.freeze

      def initialize(data:, config: {})
        @data   = deep_symbolize(data || {})
        @config = deep_merge(DEFAULT_CONFIG, config || {})
      end

      def call
        validate!
        return unsupported("unsupported instrument") unless index_instrument?(@data[:meta])

        ensure_option_chain!

        bias = BiasAggregator.new(@data[:indicators], @config).call
        return no_trade("neutral/low confidence") if bias[:bias] == :neutral || bias[:confidence].to_f < 0.6

        side = bias[:bias] == :bullish ? :ce : :pe
        moneyness = MoneynessHelper.pick_moneyness(indicators: @data[:indicators],
                                                   min_adx: @config[:min_adx_for_trend],
                                                   strong_adx: @config[:strong_adx],
                                                   bias: bias[:bias])
        strike_pick = select_strike(side: side, moneyness: moneyness)
        return no_trade("no liquid strikes passed filters") unless strike_pick

        build_recommendation(side: side, moneyness: moneyness, bias: bias, strike_pick: strike_pick)
      end

      private

      def ensure_option_chain!
        return if Array(@data[:option_chain]).any?

        # Use OptionChain model: pick nearest/next expiry and fetch chain
        sid = @data.dig(:meta, :security_id)
        seg = @data.dig(:meta, :exchange_segment) || "IDX_I"
        return unless sid && seg

        expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(underlying_scrip: sid.to_i, underlying_seg: seg)
        return if expiries.empty?

        # Choose the nearest expiry (first element); adjust selection if API returns sorted differently
        expiry = expiries.first
        raw = DhanHQ::Models::OptionChain.fetch(underlying_scrip: sid.to_i, underlying_seg: seg, expiry: expiry)
        oc = raw[:oc] || {}
        # Transform OC structure into advisor-friendly array [{ strike:, ce: {...}, pe: {...} }]
        @data[:option_chain] = oc.map do |strike, strike_data|
          {
            strike: strike.to_f,
            ce: normalize_leg(strike_data["ce"] || {}),
            pe: normalize_leg(strike_data["pe"] || {})
          }
        end
      rescue StandardError
        @data[:option_chain] ||= []
      end

      def normalize_leg(cepe)
        {
          ltp: cepe["last_price"], bid: cepe["best_bid_price"], ask: cepe["best_ask_price"],
          iv: cepe["iv"], oi: cepe["oi"], volume: cepe["volume"],
          delta: cepe["delta"], gamma: cepe["gamma"], vega: cepe["vega"], theta: cepe["theta"],
          lot_size: cepe["lot_size"], tradable: true
        }
      end

      def validate!
        res = DhanHQ::Contracts::OptionsBuyingAdvisorContract.new.call(@data)
        raise ArgumentError, res.errors.to_h.inspect unless res.success?
      end

      def index_instrument?(meta)
        meta[:instrument].to_s == "INDEX" || meta[:exchange_segment].to_s == "IDX_I"
      end

      def select_strike(side:, moneyness:)
        chain = Array(@data[:option_chain])
        return nil if chain.empty?

        target_range = @config[:preferred_deltas][side][moneyness]
        best = nil
        chain.each do |row|
          leg = row[side]
          next unless leg && leg[:tradable]
          next if leg[:oi].to_i < @config[:min_oi]

          spread = spread_pct(leg[:bid], leg[:ask])
          next if spread.nil? || spread > @config[:max_spread_pct]

          delta = leg[:delta]
          next unless delta && target_range.cover?(delta)

          candidate = { strike: row[:strike], leg: leg, spread: spread, oi: leg[:oi].to_i, delta: delta }
          best = rank_pick(best, candidate)
        end
        best
      end

      def spread_pct(bid, ask)
        return nil if bid.to_f <= 0.0 || ask.to_f <= 0.0

        mid = (bid.to_f + ask.to_f) / 2.0
        return nil if mid <= 0.0

        ((ask.to_f - bid.to_f) / mid) * 100.0
      end

      def rank_pick(best, cand)
        return cand unless best

        target_center = cand[:delta] >= 0 ? 0.5 : -0.5
        best_score = [delta_distance(best[:delta], target_center), best[:spread], -best[:oi]]
        cand_score = [delta_distance(cand[:delta], target_center), cand[:spread], -cand[:oi]]
        cand_score < best_score ? cand : best
      end

      def delta_distance(delta, center)
        (delta.to_f - center).abs
      end

      def build_recommendation(side:, moneyness:, bias:, strike_pick:)
        risk = compute_risk(strike_pick[:leg])
        {
          meta: { symbol: @data.dig(:meta, :symbol), security_id: @data.dig(:meta, :security_id), ts: Time.now },
          decision: :enter_long,
          side: side,
          moneyness: moneyness,
          rationale: {
            bias: bias[:bias],
            confidence: bias[:confidence],
            notes: bias[:notes]
          },
          instrument: {
            spot: @data[:spot],
            ref_timeframes: bias[:refs],
            atr_rupees_hint: atr_to_rupees
          },
          strike: {
            recommended: strike_pick[:strike],
            alternatives: [],
            selection_basis: "delta window, spread, OI"
          },
          risk: risk
        }
      end

      def atr_to_rupees
        m15 = @data.dig(:indicators, :m15, :atr)
        return nil unless m15

        (m15.to_f * @config[:atr_to_rupees_factor].to_f).round(2)
      end

      def compute_risk(leg)
        entry = leg[:ltp].to_f
        sl = (entry * (1.0 - @config.dig(:risk, :sl_pct).to_f)).round(2)
        tp = (entry * (1.0 + @config.dig(:risk, :tp_pct).to_f)).round(2)
        {
          entry_ltp: entry,
          sl_ltp: sl,
          tp_ltp: tp,
          trail: { start_at_gain_pct: (@config.dig(:risk, :trail_arm_pct) * 100).to_i,
                   step_pct: (@config.dig(:risk, :trail_step_pct) * 100).to_i }
        }
      end

      def unsupported(reason)
        { decision: :no_trade, reason: reason }
      end

      def no_trade(reason)
        { decision: :no_trade, reason: reason }
      end

      def deep_merge(a, b)
        return a unless b

        a.merge(b) { |_, av, bv| av.is_a?(Hash) && bv.is_a?(Hash) ? deep_merge(av, bv) : bv }
      end

      def deep_symbolize(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize(v) }
        when Array
          obj.map { |v| deep_symbolize(v) }
        else
          obj
        end
      end
    end
  end
end
