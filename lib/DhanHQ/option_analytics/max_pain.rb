# frozen_string_literal: true

module DhanHQ
  module OptionAnalytics
    # Max Pain calculator for option chain analysis.
    #
    # Max Pain is the strike price at which the maximum number of options
    # (both calls and puts) would expire worthless. It is believed that
    # the underlying asset tends to gravitate towards this price at expiry.
    #
    # @example Calculate Max Pain
    #   option_data = [
    #     { strike: 24000, call_oi: 1000, put_oi: 500 },
    #     { strike: 24100, call_oi: 800, put_oi: 700 },
    #     { strike: 24200, call_oi: 600, put_oi: 900 },
    #     ...
    #   ]
    #   max_pain = DhanHQ::OptionAnalytics::MaxPain.calculate(option_data)
    #   #=> 24100
    #
    class MaxPain
      # Calculate Max Pain strike price.
      #
      # @param option_data [Array<Hash>] Array of option data with :strike, :call_oi, :put_oi
      # @return [Integer, Float] Strike price with maximum pain
      def self.calculate(option_data)
        return nil if option_data.nil? || option_data.empty?

        strikes = option_data.map { |d| d[:strike] || d["strike"] }

        # Calculate total pain for each possible strike
        pain_values = strikes.map do |strike|
          total_pain = option_data.sum do |data|
            s = data[:strike] || data["strike"]
            call_oi = (data[:call_oi] || data["call_oi"] || 0).to_i
            put_oi = (data[:put_oi] || data["put_oi"] || 0).to_i

            calculate_pain_at_strike(s, strike, call_oi, put_oi)
          end

          { strike: strike, pain: total_pain }
        end

        # Find strike with minimum pain (Max Pain)
        pain_values.min_by { |v| v[:pain] }[:strike]
      end

      # Calculate Max Pain with detailed breakdown.
      #
      # @param option_data [Array<Hash>] Array of option data with :strike, :call_oi, :put_oi
      # @return [Hash] Hash with :max_pain_strike, :total_pain, and :pain_distribution
      def self.detailed(option_data)
        return nil if option_data.nil? || option_data.empty?

        strikes = option_data.map { |d| d[:strike] || d["strike"] }

        pain_distribution = strikes.map do |strike|
          total_pain = option_data.sum do |data|
            s = data[:strike] || data["strike"]
            call_oi = (data[:call_oi] || data["call_oi"] || 0).to_i
            put_oi = (data[:put_oi] || data["put_oi"] || 0).to_i

            calculate_pain_at_strike(s, strike, call_oi, put_oi)
          end

          { strike: strike, pain: total_pain }
        end

        max_pain_entry = pain_distribution.min_by { |v| v[:pain] }

        {
          max_pain_strike: max_pain_entry[:strike],
          total_pain: max_pain_entry[:pain],
          pain_distribution: pain_distribution
        }
      end

      # Calculate Put-Call Ratio from option data.
      #
      # @param option_data [Array<Hash>] Array of option data with :call_oi, :put_oi
      # @return [Float] Put-Call Ratio
      def self.put_call_ratio(option_data)
        return 0.0 if option_data.nil? || option_data.empty?

        total_call_oi = option_data.sum { |d| (d[:call_oi] || d["call_oi"] || 0).to_i }
        total_put_oi = option_data.sum { |d| (d[:put_oi] || d["put_oi"] || 0).to_i }

        return 0.0 if total_call_oi.zero?

        total_put_oi.to_f / total_call_oi
      end

      class << self
        private

        # Calculate total pain at a given strike price.
        # Pain is the loss that option writers would incur if the underlying
        # expires at that strike.
        def calculate_pain_at_strike(current_strike, expiry_strike, call_oi, put_oi)
          # Call writers lose when price goes above strike
          call_pain = if expiry_strike > current_strike
                        (expiry_strike - current_strike) * call_oi
                      else
                        0
                      end

          # Put writers lose when price goes below strike
          put_pain = if expiry_strike < current_strike
                       (current_strike - expiry_strike) * put_oi
                     else
                       0
                     end

          call_pain + put_pain
        end
      end
    end
  end
end
