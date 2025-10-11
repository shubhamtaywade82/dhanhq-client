# frozen_string_literal: true

require "json"
require "dry/validation"

module DhanHQ
  module Analysis
    # Builds a narrative summary of market bias from multi-timeframe indicators.
    class MultiTimeframeAnalyzer
      RSI_UP_MOMENTUM   = %i[bullish overbought].freeze
      RSI_DOWN_MOMENTUM = %i[bearish oversold].freeze
      # Ensures analyzer inputs follow the expected schema.
      class InputContract < Dry::Validation::Contract
        params do
          required(:meta).filled(:hash)
          required(:indicators).filled(:hash)
        end
      end

      TF_ORDER = %i[m1 m5 m15 m25 m60].freeze

      # @param data [Hash] nested indicator payload.
      def initialize(data:)
        @data = symbolize(data)
      end

      # Generates an aggregated bias narrative.
      #
      # @return [Hash]
      def call
        validate_data!
        per_tf = compute_indicators(@data[:indicators])
        aggregate_results(per_tf)
      end

      private

      # Deep-symbolizes keys to ease downstream access.
      #
      # @param obj [Object]
      # @return [Object]
      def symbolize(obj)
        case obj
        when Hash
          obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = symbolize(v) }
        when Array
          obj.map { |v| symbolize(v) }
        else
          obj
        end
      end

      # Validates the incoming payload against the contract.
      #
      # @return [void]
      def validate_data!
        res = InputContract.new.call(@data)
        raise ArgumentError, res.errors.to_h.inspect unless res.success?
      end

      # Builds per-timeframe indicator summaries.
      #
      # @param indicators [Hash]
      # @return [Hash]
      def compute_indicators(indicators)
        TF_ORDER.each_with_object({}) do |tf, out|
          next unless indicators.key?(tf)

          val = indicators[tf]
          rsi   = val[:rsi]
          adx   = val[:adx]
          atr   = val[:atr]
          macd  = val[:macd] || {}
          macd_line   = macd[:macd]
          macd_signal = macd[:signal]
          macd_hist   = macd[:hist]

          momentum = classify_rsi(rsi)
          trend    = classify_adx(adx)
          macd_sig = classify_macd(macd_line, macd_signal, macd_hist)
          vol      = classify_atr(atr)

          out[tf] = {
            rsi: rsi, adx: adx, atr: atr, macd: macd,
            momentum: momentum, trend: trend, macd_signal: macd_sig, volatility: vol,
            bias: derive_bias(momentum, macd_sig)
          }
        end
      end

      # Classifies RSI momentum state.
      #
      # @param rsi [Numeric, nil]
      # @return [Symbol]
      def classify_rsi(rsi)
        return :unknown if rsi.nil?
        return :overbought if rsi >= 70
        return :oversold if rsi <= 30
        return :bullish if rsi >= 55
        return :bearish if rsi <= 45

        :neutral
      end

      # Classifies trend strength using ADX.
      #
      # @param adx [Numeric, nil]
      # @return [Symbol]
      def classify_adx(adx)
        return :unknown if adx.nil?
        return :strong if adx >= 25
        return :weak if adx <= 15

        :moderate
      end

      # Interprets MACD signals to directional bias.
      #
      # @param macd [Numeric, nil]
      # @param signal [Numeric, nil]
      # @param hist [Numeric, nil]
      # @return [Symbol]
      def classify_macd(macd, signal, hist)
        return :unknown if macd.nil? || signal.nil?

        # Treat histogram sign and distance as proxy for momentum direction
        if macd > signal && (hist.nil? || hist >= 0)
          :bullish
        elsif macd < signal && (hist.nil? || hist <= 0)
          :bearish
        else
          :neutral
        end
      end

      # Labels volatility expansion using ATR.
      #
      # @param atr [Numeric, nil]
      # @return [Symbol]
      def classify_atr(atr)
        return :unknown if atr.nil?

        # ATR is relative; without baseline we can only tag as present
        atr.positive? ? :expanding : :flat
      end

      # Combines RSI and MACD derived signals to an overall bias.
      #
      # @param momentum [Symbol]
      # @param macd_sig [Symbol]
      # @return [Symbol]
      def derive_bias(momentum, macd_sig)
        return :bullish if momentum == :bullish && macd_sig == :bullish
        return :bearish if momentum == :bearish && macd_sig == :bearish

        :neutral
      end

      # Builds the high-level summary from per-timeframe data.
      #
      # @param per_tf [Hash]
      # @return [Hash]
      def aggregate_results(per_tf)
        weights = { m1: 1, m5: 2, m15: 3, m25: 3, m60: 4 }
        scores = { bullish: 1.0, neutral: 0.5, bearish: 0.0 }

        total_w = 0.0
        acc = 0.0
        per_tf.each do |tf, s|
          w = weights[tf] || 1
          total_w += w
          acc += (scores[s[:bias]] || 0.5) * w
        end
        avg = total_w.zero? ? 0.5 : (acc / total_w)

        bias = if avg >= 0.66
                 :bullish
               elsif avg <= 0.33
                 :bearish
               else
                 :neutral
               end

        setup = if bias == :bullish
                  :buy_on_dip
                elsif bias == :bearish
                  :sell_on_rise
                else
                  :range_trade
                end

        rationale = build_rationale(per_tf)
        trend_strength = build_trend_strength(per_tf)

        {
          meta: (@data[:meta] || {}).slice(:security_id, :instrument, :exchange_segment),
          summary: {
            bias: bias,
            setup: setup,
            confidence: avg.round(2),
            rationale: rationale,
            trend_strength: trend_strength
          }
        }
      end

      # Builds indicator rationale sentences.
      #
      # @param per_tf [Hash]
      # @return [Hash]
      def build_rationale(per_tf)
        {
          rsi: rsi_rationale(per_tf),
          macd: macd_rationale(per_tf),
          adx: adx_rationale(per_tf),
          atr: atr_rationale(per_tf)
        }
      end

      # Summarizes RSI across timeframes.
      #
      # @param per_tf [Hash]
      # @return [String]
      def rsi_rationale(per_tf)
        ups = per_tf.count { |_tf, state| RSI_UP_MOMENTUM.include?(state[:momentum]) }
        downs = per_tf.count { |_tf, state| RSI_DOWN_MOMENTUM.include?(state[:momentum]) }
        if ups > downs
          "Upward momentum across #{ups} TFs"
        elsif downs > ups
          "Downward momentum across #{downs} TFs"
        else
          "Mixed RSI momentum"
        end
      end

      # Summarizes MACD strength.
      #
      # @param per_tf [Hash]
      # @return [String]
      def macd_rationale(per_tf)
        ups = per_tf.count { |_tf, s| s[:macd_signal] == :bullish }
        downs = per_tf.count { |_tf, s| s[:macd_signal] == :bearish }
        if ups > downs
          "MACD bullish signals dominant"
        elsif downs > ups
          "MACD bearish signals dominant"
        else
          "MACD mixed/neutral"
        end
      end

      # Summarizes ADX trend strength.
      #
      # @param per_tf [Hash]
      # @return [String]
      def adx_rationale(per_tf)
        strong = per_tf.count { |_tf, s| s[:trend] == :strong }
        return "Strong higher timeframe trend" if strong >= 2

        moderate = per_tf.count { |_tf, s| s[:trend] == :moderate }
        return "Moderate trend context" if moderate >= 2

        "Weak/unknown trend context"
      end

      # Summarizes ATR driven volatility.
      #
      # @param per_tf [Hash]
      # @return [String]
      def atr_rationale(per_tf)
        exp = per_tf.count { |_tf, s| s[:volatility] == :expanding }
        exp.positive? ? "Volatility expansion" : "Low/flat volatility"
      end

      # Builds the trend strength breakdown by timeframe bucket.
      #
      # @param per_tf [Hash]
      # @return [Hash]
      def build_trend_strength(per_tf)
        {
          short_term: summarize_bias(%i[m1 m5], per_tf),
          medium_term: summarize_bias(%i[m15 m25], per_tf),
          long_term: summarize_bias(%i[m60], per_tf)
        }
      end

      # Collapses a set of timeframes into a coarse bias value.
      #
      # @param tfs [Array<Symbol>]
      # @param per_tf [Hash]
      # @return [Symbol]
      def summarize_bias(tfs, per_tf)
        slice = per_tf.slice(*tfs)
        ups = slice.count { |_tf, s| s[:bias] == :bullish }
        downs = slice.count { |_tf, s| s[:bias] == :bearish }
        return :strong_bullish if ups >= 2
        return :strong_bearish if downs >= 2
        return :weak_bullish if ups == 1 && downs.zero?
        return :weak_bearish if downs == 1 && ups.zero?

        :neutral
      end
    end
  end
end
