# frozen_string_literal: true

# rubocop:disable Style/RescueModifier
# rubocop:disable Naming/VariableNumber
# rubocop:disable Style/NumericPredicate
# rubocop:disable Lint/AmbiguousOperatorPrecedence

require "date"

module DhanHQ
  module Skills
    module Builtin
      # Programmatic Agent Skill to process and summarize market data.
      # Exposes computed technical indicators and options statistics rather than raw data.
      class MarketDataSummarizer < Base
        risk "read_only"
        scope "market:read"
        description "Summarize technicals and/or option chain (PCR, OI walls, ATM strikes) for a symbol."

        param :underlying_symbol, type: :string, required: true, description: "Underlying ticker symbol (e.g. NIFTY, RELIANCE)"
        param :mode, type: :string, default: "both", description: "Analysis mode: both, technicals, or option_chain"
        param :interval, type: :string, default: DhanHQ::Constants::Validity::DAY, description: "Timeframe for technical indicators"
        param :range_days, type: :integer, default: 30, description: "Lookback period in days for indicator calculation"
        param :expiry, type: :string, default: "nearest", description: "Specific option expiry date (YYYY-MM-DD) or 'nearest'"
        param :strike_range, type: :integer, default: 5, description: "Number of strikes to include above and below ATM"

        step :resolve_instrument, priority: 1
        step :fetch_technicals, priority: 2
        step :fetch_option_chain_summary, priority: 3
        step :prepare_final_summary, priority: 4

        def resolve_instrument(ctx)
          symbol = ctx[:underlying_symbol].to_s.upcase.strip
          inst = DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::IDX_I, symbol) rescue nil
          inst ||= DhanHQ::Models::Instrument.find(DhanHQ::Constants::ExchangeSegment::NSE_EQ, symbol) rescue nil
          inst ||= DhanHQ::Models::Instrument.find_anywhere(symbol) rescue nil

          raise "Underlying symbol not found: #{symbol}" unless inst

          ctx[:instrument] = inst
          ctx
        end

        def fetch_technicals(ctx)
          return ctx unless %w[both technicals].include?(ctx[:mode])

          inst = ctx[:instrument]
          to_date = Date.today.strftime("%Y-%m-%d")
          from_date = (Date.today - [ctx[:range_days].to_i * 2, 100].max).strftime("%Y-%m-%d")

          candles = DhanHQ::Models::HistoricalData.daily(
            security_id: inst.security_id,
            exchange_segment: inst.exchange_segment,
            instrument: inst.instrument,
            from_date: from_date,
            to_date: to_date
          ) rescue []

          if candles.any?
            closes = candles.map { |c| c[:close].to_f }
            latest_close = closes.last

            sma_20 = closes.size >= 20 ? (closes.last(20).sum / 20.0).round(2) : nil
            sma_50 = closes.size >= 50 ? (closes.last(50).sum / 50.0).round(2) : nil
            ret_5d = closes.size >= 6 ? (((closes.last / closes[-6]) - 1.0) * 100).round(2) : nil

            # RSI (14) Calculation
            rsi_14 = calculate_rsi(closes)

            ctx[:technical_summary] = {
              ltp: latest_close,
              sma_20: sma_20,
              sma_50: sma_50,
              return_5d_pct: ret_5d,
              rsi_14: rsi_14,
              data_points_analyzed: closes.size
            }
          else
            # Fallback to LTP quote if daily candles fail
            quote = inst.ltp rescue {}
            ctx[:technical_summary] = {
              ltp: quote[:ltp] || quote["ltp"] || 0.0,
              note: "Failed to load historical candles; loaded quote snapshot instead."
            }
          end
          ctx
        end

        def fetch_option_chain_summary(ctx)
          return ctx unless %w[both option_chain].include?(ctx[:mode])

          inst = ctx[:instrument]
          underlying_seg = inst.exchange_segment == DhanHQ::Constants::ExchangeSegment::IDX_I ? DhanHQ::Constants::ExchangeSegment::IDX_I : DhanHQ::Constants::ExchangeSegment::NSE_EQ

          target_expiry = ctx[:expiry]
          if target_expiry.to_s.empty? || target_expiry == "nearest"
            expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
              underlying_scrip: inst.security_id.to_i,
              underlying_seg: underlying_seg
            )
            target_expiry = expiries.first
          end

          return ctx if target_expiry.nil?

          chain = DhanHQ::Models::OptionChain.fetch(
            underlying_scrip: inst.security_id.to_i,
            underlying_seg: underlying_seg,
            expiry: target_expiry
          )

          if chain
            spot = chain[:last_price] || ctx[:technical_summary]&.[](:ltp)
            strikes = chain[:strikes] || []

            # Locate ATM
            closest_strike_data = strikes.min_by { |s| (s[:strike].to_f - spot).abs }
            closest_idx = strikes.index(closest_strike_data)

            # Filter ATM +/- strike_range
            range = ctx[:strike_range].to_i
            start_idx = [0, closest_idx - range].max
            end_idx = [strikes.size - 1, closest_idx + range].min

            filtered_strikes = strikes[start_idx..end_idx].map do |s|
              {
                strike: s[:strike],
                ce: s[:call] ? { security_id: s[:call][:security_id], ltp: s[:call][:last_price], oi: s[:call][:oi] } : nil,
                pe: s[:put] ? { security_id: s[:put][:security_id], ltp: s[:put][:last_price], oi: s[:put][:oi] } : nil
              }
            end

            # PCR & OI Walls
            total_ce_oi = strikes.sum { |s| s[:call]&.[](:oi).to_f }
            total_pe_oi = strikes.sum { |s| s[:put]&.[](:oi).to_f }
            pcr = total_ce_oi > 0 ? (total_pe_oi / total_ce_oi).round(3) : 0.0

            ce_walls = strikes.reject { |s| s[:call].nil? }.sort_by { |s| -(s[:call][:oi] || 0) }.first(3).map { |s| { strike: s[:strike], oi: s[:call][:oi] } }
            pe_walls = strikes.reject { |s| s[:put].nil? }.sort_by { |s| -(s[:put][:oi] || 0) }.first(3).map { |s| { strike: s[:strike], oi: s[:put][:oi] } }

            ctx[:option_chain_summary] = {
              expiry: target_expiry,
              spot: spot,
              pcr: pcr,
              resistance_walls: ce_walls,
              support_walls: pe_walls,
              strikes: filtered_strikes
            }
          end
          ctx
        end

        def prepare_final_summary(ctx)
          ctx[:summary] = {
            symbol: ctx[:underlying_symbol],
            timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S"),
            technicals: ctx[:technical_summary],
            options: ctx[:option_chain_summary]
          }
          ctx
        end

        private

        def calculate_rsi(closes)
          return nil if closes.size < 15

          gains = []
          losses = []
          closes.each_cons(2) do |prev, curr|
            diff = curr - prev
            gains << (diff > 0 ? diff : 0.0)
            losses << (diff < 0 ? -diff : 0.0)
          end

          avg_gain = gains.first(14).sum / 14.0
          avg_loss = losses.first(14).sum / 14.0

          gains[14..].zip(losses[14..]).each do |g, l|
            avg_gain = (avg_gain * 13 + g) / 14.0
            avg_loss = (avg_loss * 13 + l) / 14.0
          end

          rs = avg_loss > 0 ? (avg_gain / avg_loss) : 100.0
          (100.0 - (100.0 / (1.0 + rs))).round(2)
        end
      end
    end
  end
end

# rubocop:enable Style/RescueModifier
# rubocop:enable Naming/VariableNumber
# rubocop:enable Style/NumericPredicate
# rubocop:enable Lint/AmbiguousOperatorPrecedence
