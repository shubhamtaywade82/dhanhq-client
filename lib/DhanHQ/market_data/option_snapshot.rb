# frozen_string_literal: true

module DhanHQ
  module MarketData
    # A snapshot of option chain data for a single underlying.
    #
    # Wraps the raw OptionChain response into a convenient structure
    # with typed accessors and helper methods for option analysis.
    #
    # @example Build a snapshot from OptionChain response
    #   response = DhanHQ::Models::OptionChain.fetch(
    #     underlying_scrip: 13,
    #     underlying_seg: "IDX_I",
    #     expiry: "2024-07-25"
    #   )
    #   snapshot = DhanHQ::MarketData::OptionSnapshot.from_response(response)
    #   snapshot.calls_at(24000) #=> Array of call option data
    #   snapshot.puts_at(24000) #=> Array of put option data
    #
    class OptionSnapshot
      OptionLeg = Struct.new(:strike_price, :option_type, :ltp, :bid, :ask,
                             :volume, :open_interest, :implied_volatility,
                             :delta, :gamma, :theta, :vega) do
        def call?
          option_type == DhanHQ::Constants::OptionType::CALL
        end

        def put?
          option_type == DhanHQ::Constants::OptionType::PUT
        end

        def itm?(spot_price)
          return false unless spot_price

          call? ? strike_price < spot_price : strike_price > spot_price
        end

        def otm?(spot_price)
          return false unless spot_price

          call? ? strike_price > spot_price : strike_price < spot_price
        end

        def atm?(spot_price)
          return false unless spot_price

          (strike_price - spot_price).abs < 1
        end
      end

      attr_reader :underlying_scrip, :underlying_seg, :expiry, :legs, :spot_price, :fetched_at

      def initialize(legs = [], metadata = {})
        @underlying_scrip = metadata[:underlying_scrip]
        @underlying_seg = metadata[:underlying_seg]
        @expiry = metadata[:expiry]
        @spot_price = metadata[:spot_price]
        @legs = legs
        @fetched_at = Time.now
      end

      # Build an OptionSnapshot from a raw OptionChain API response.
      def self.from_response(response)
        data = response.is_a?(Hash) ? (response[:data] || response["data"] || response) : response
        return new([], {}) unless data.is_a?(Hash)

        legs = parse_legs(data)
        metadata = {
          underlying_scrip: data[:underlyingScrip] || data["underlyingScrip"],
          underlying_seg: data[:underlyingSeg] || data["underlyingSeg"],
          expiry: data[:expiry] || data["expiry"],
          spot_price: data[:spot] || data["spot"]
        }

        new(legs, metadata)
      end

      # Get all call option legs.
      def calls
        @legs.select(&:call?)
      end

      # Get all put option legs.
      def puts
        @legs.select(&:put?)
      end

      # Get all unique strike prices.
      def strikes
        @legs.map(&:strike_price).uniq.sort
      end

      # Get option legs at a specific strike price.
      def at_strike(strike_price)
        @legs.select { |leg| leg.strike_price == strike_price }
      end

      # Get call option at a specific strike price.
      def call_at(strike_price)
        calls.find { |leg| leg.strike_price == strike_price }
      end

      # Get put option at a specific strike price.
      def put_at(strike_price)
        puts.find { |leg| leg.strike_price == strike_price }
      end

      # Get all ITM calls (calls with strike below spot).
      def itm_calls
        return [] unless @spot_price

        calls.select { |leg| leg.itm?(@spot_price) }
      end

      # Get all OTM calls (calls with strike above spot).
      def otm_calls
        return [] unless @spot_price

        calls.select { |leg| leg.otm?(@spot_price) }
      end

      # Get all ITM puts (puts with strike above spot).
      def itm_puts
        return [] unless @spot_price

        puts.select { |leg| leg.itm?(@spot_price) }
      end

      # Get all OTM puts (puts with strike below spot).
      def otm_puts
        return [] unless @spot_price

        puts.select { |leg| leg.otm?(@spot_price) }
      end

      # Find the ATM strike (closest to spot price).
      def atm_strike
        return nil unless @spot_price || strikes.any?

        spot = @spot_price || strikes.first
        strikes.min_by { |strike| (strike - spot).abs }
      end

      # Get the total open interest across all legs.
      def total_oi
        @legs.sum { |leg| leg.open_interest.to_i }
      end

      # Get the total volume across all legs.
      def total_volume
        @legs.sum { |leg| leg.volume.to_i }
      end

      # Calculate put-call ratio by open interest.
      def pcr_by_oi
        call_oi = calls.sum { |leg| leg.open_interest.to_i }
        put_oi = puts.sum { |leg| leg.open_interest.to_i }
        return 0.0 if call_oi.zero?

        put_oi.to_f / call_oi
      end

      # Calculate put-call ratio by volume.
      def pcr_by_volume
        call_vol = calls.sum { |leg| leg.volume.to_i }
        put_vol = puts.sum { |leg| leg.volume.to_i }
        return 0.0 if call_vol.zero?

        put_vol.to_f / call_vol
      end

      def self.parse_legs(data)
        # Parse from the option chain structure
        ce_data = data[:ce] || data["ce"] || {}
        pe_data = data[:pe] || data["pe"] || {}

        ce_strikes = ce_data[:strike] || ce_data["strike"] || []
        pe_strikes = pe_data[:strike] || pe_data["strike"] || []

        # Parse CE (call) and PE (put) legs
        parse_option_legs(ce_data, DhanHQ::Constants::OptionType::CALL, ce_strikes) +
          parse_option_legs(pe_data, DhanHQ::Constants::OptionType::PUT, pe_strikes)
      end
      private_class_method :parse_legs

      def self.parse_option_legs(data, option_type, strikes)
        return [] unless data.is_a?(Hash)

        strikes.each_with_index.map do |strike, i|
          build_leg(data, option_type, strike, i)
        end
      end
      private_class_method :parse_option_legs

      def self.build_leg(data, option_type, strike, index)
        OptionLeg.new(
          strike_price: strike.to_f,
          option_type: option_type,
          ltp: extract_value(data, :ltp, index),
          bid: extract_value(data, :bid, index),
          ask: extract_value(data, :ask, index),
          volume: extract_value(data, :volume, index, as_integer: true),
          open_interest: extract_value(data, :oi, index, as_integer: true),
          implied_volatility: extract_value(data, :iv, index),
          delta: extract_value(data, :delta, index),
          gamma: extract_value(data, :gamma, index),
          theta: extract_value(data, :theta, index),
          vega: extract_value(data, :vega, index)
        )
      end
      private_class_method :build_leg

      def self.extract_value(data, key, index, as_integer: false)
        values = data[key] || data[key.to_s] || []
        value = values[index]
        return nil if value.nil?

        as_integer ? value.to_i : value.to_f
      end
      private_class_method :extract_value
    end
  end
end
