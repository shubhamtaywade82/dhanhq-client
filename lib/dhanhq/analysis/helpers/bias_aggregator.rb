# frozen_string_literal: true

module DhanHQ
  module Analysis
    class BiasAggregator
      DEFAULT_WEIGHTS = { m1: 0.1, m5: 0.2, m15: 0.25, m25: 0.15, m60: 0.3 }.freeze

      def initialize(indicators, config = {})
        @indicators = indicators || {}
        @weights = config[:timeframe_weights] || DEFAULT_WEIGHTS
        @min_adx = (config[:min_adx_for_trend] || 22).to_f
        @strong_adx = (config[:strong_adx] || 35).to_f
      end

      def call
        score = 0.0
        wsum = 0.0
        refs = []
        notes = []

        @weights.each do |tf, w|
          next unless @indicators[tf]

          s = score_tf(@indicators[tf])
          next if s.nil?

          score += s * w
          wsum += w
          refs << tf
        end

        avg = wsum.zero? ? 0.5 : (score / wsum)
        bias = if avg > 0.55
                 :bullish
               elsif avg < 0.45
                 :bearish
               else
                 :neutral
               end

        { bias: bias, confidence: avg.round(2), refs: refs, notes: notes }
      end

      private

      def score_tf(val)
        rsi = val[:rsi]
        macd = val[:macd] || {}
        hist = macd[:hist]
        adx = val[:adx]

        return 0.65 if rsi && rsi >= 55
        return 0.35 if rsi && rsi <= 45

        rsi_component = 0.5

        macd_component = case hist
                         when nil then 0.5
                         else
                           hist >= 0 ? 0.6 : 0.4
                         end

        adx_component = case adx
                        when nil then 0.5
                        else
                          if adx >= @strong_adx
                            0.65
                          elsif adx >= @min_adx
                            0.55
                          else
                            0.45
                          end
                        end

        (rsi_component * 0.4) + (macd_component * 0.3) + (adx_component * 0.3)
      end
    end
  end
end
