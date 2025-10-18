# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Represents expired options data for rolling contracts
    # Provides access to OHLC, volume, open interest, implied volatility, and spot data
    # rubocop:disable Metrics/ClassLength
    class ExpiredOptionsData < BaseModel
      # All expired options data attributes
      attributes :exchange_segment, :interval, :security_id, :instrument,
                 :expiry_flag, :expiry_code, :strike, :drv_option_type,
                 :required_data, :from_date, :to_date, :data

      class << self
        ##
        # Fetch expired options data for rolling contracts
        # POST /charts/rollingoption
        #
        # @param params [Hash] Parameters for the request
        # @option params [String] :exchange_segment Exchange segment (e.g., "NSE_FNO")
        # @option params [Integer] :interval Minute interval (1, 5, 15, 25, 60)
        # @option params [String] :security_id Security ID for the underlying
        # @option params [String] :instrument Instrument type ("OPTIDX" or "OPTSTK")
        # @option params [String] :expiry_flag Expiry interval ("WEEK" or "MONTH")
        # @option params [Integer] :expiry_code Expiry code
        # @option params [String] :strike Strike price ("ATM", "ATM+1", "ATM-1", etc.)
        # @option params [String] :drv_option_type Option type ("CALL" or "PUT")
        # @option params [Array<String>] :required_data Required data fields
        # @option params [String] :from_date Start date (YYYY-MM-DD)
        # @option params [String] :to_date End date (YYYY-MM-DD)
        # @return [ExpiredOptionsData] Expired options data object
        def fetch(params)
          validate_params(params)

          response = expired_options_resource.fetch(params)
          new(response.merge(params), skip_validation: true)
        end

        private

        def expired_options_resource
          @expired_options_resource ||= DhanHQ::Resources::ExpiredOptionsData.new
        end

        def validate_params(params)
          contract = DhanHQ::Contracts::ExpiredOptionsDataContract.new
          validation_result = contract.call(params)

          return if validation_result.success?

          raise DhanHQ::ValidationError, "Invalid parameters: #{validation_result.errors.to_h}"
        end
      end

      ##
      # ExpiredOptionsData objects are read-only, so no validation contract needed
      def validation_contract
        nil
      end

      ##
      # Get call option data
      # @return [Hash, nil] Call option data or nil if not available
      def call_data
        return nil unless data.is_a?(Hash)

        data["ce"] || data[:ce]
      end

      ##
      # Get put option data
      # @return [Hash, nil] Put option data or nil if not available
      def put_data
        return nil unless data.is_a?(Hash)

        data["pe"] || data[:pe]
      end

      ##
      # Get data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Hash, nil] Option data or nil if not available
      def data_for_type(option_type)
        case option_type.upcase
        when "CALL"
          call_data
        when "PUT"
          put_data
        end
      end

      ##
      # Get OHLC data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Hash] OHLC data with open, high, low, close arrays
      # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def ohlc_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return {} unless option_data

        {
          open: option_data["open"] || option_data[:open] || [],
          high: option_data["high"] || option_data[:high] || [],
          low: option_data["low"] || option_data[:low] || [],
          close: option_data["close"] || option_data[:close] || []
        }
      end
      # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      ##
      # Get volume data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Integer>] Volume data array
      def volume_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["volume"] || option_data[:volume] || []
      end

      ##
      # Get open interest data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Float>] Open interest data array
      def open_interest_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["oi"] || option_data[:oi] || []
      end

      ##
      # Get implied volatility data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Float>] Implied volatility data array
      def implied_volatility_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["iv"] || option_data[:iv] || []
      end

      ##
      # Get strike price data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Float>] Strike price data array
      def strike_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["strike"] || option_data[:strike] || []
      end

      ##
      # Get spot price data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Float>] Spot price data array
      def spot_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["spot"] || option_data[:spot] || []
      end

      ##
      # Get timestamp data for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Integer>] Timestamp data array (epoch)
      def timestamp_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["timestamp"] || option_data[:timestamp] || []
      end

      ##
      # Get data points count for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Integer] Number of data points
      def data_points_count(option_type = nil)
        timestamps = timestamp_data(option_type)
        timestamps.size
      end

      ##
      # Get average volume for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Float] Average volume
      def average_volume(option_type = nil)
        volumes = volume_data(option_type)
        return 0.0 if volumes.empty?

        volumes.sum.to_f / volumes.size
      end

      ##
      # Get average open interest for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Float] Average open interest
      def average_open_interest(option_type = nil)
        oi_data = open_interest_data(option_type)
        return 0.0 if oi_data.empty?

        oi_data.sum.to_f / oi_data.size
      end

      ##
      # Get average implied volatility for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Float] Average implied volatility
      def average_implied_volatility(option_type = nil)
        iv_data = implied_volatility_data(option_type)
        return 0.0 if iv_data.empty?

        iv_data.sum.to_f / iv_data.size
      end

      ##
      # Get price range (high - low) for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Array<Float>] Price range for each data point
      def price_ranges(option_type = nil)
        ohlc = ohlc_data(option_type)
        highs = ohlc[:high]
        lows = ohlc[:low]

        return [] if highs.empty? || lows.empty?

        highs.zip(lows).map { |high, low| high - low }
      end

      ##
      # Get summary statistics for the specified option type
      # @param option_type [String] "CALL" or "PUT"
      # @return [Hash] Summary statistics
      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def summary_stats(option_type = nil)
        option_type ||= drv_option_type
        ohlc = ohlc_data(option_type)
        volumes = volume_data(option_type)
        oi_data = open_interest_data(option_type)
        iv_data = implied_volatility_data(option_type)

        {
          data_points: data_points_count(option_type),
          avg_volume: average_volume(option_type),
          avg_open_interest: average_open_interest(option_type),
          avg_implied_volatility: average_implied_volatility(option_type),
          price_ranges: price_ranges(option_type),
          has_ohlc: !ohlc[:open].empty?,
          has_volume: !volumes.empty?,
          has_open_interest: !oi_data.empty?,
          has_implied_volatility: !iv_data.empty?
        }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      ##
      # Check if this is index options data
      # @return [Boolean] true if instrument is OPTIDX
      def index_options?
        instrument == "OPTIDX"
      end

      ##
      # Check if this is stock options data
      # @return [Boolean] true if instrument is OPTSTK
      def stock_options?
        instrument == "OPTSTK"
      end

      ##
      # Check if this is weekly expiry
      # @return [Boolean] true if expiry_flag is WEEK
      def weekly_expiry?
        expiry_flag == "WEEK"
      end

      ##
      # Check if this is monthly expiry
      # @return [Boolean] true if expiry_flag is MONTH
      def monthly_expiry?
        expiry_flag == "MONTH"
      end

      ##
      # Check if this is call option data
      # @return [Boolean] true if drv_option_type is CALL
      def call_option?
        drv_option_type == "CALL"
      end

      ##
      # Check if this is put option data
      # @return [Boolean] true if drv_option_type is PUT
      def put_option?
        drv_option_type == "PUT"
      end

      ##
      # Check if strike is at the money
      # @return [Boolean] true if strike is ATM
      def at_the_money?
        strike == "ATM"
      end

      ##
      # Get strike offset from ATM
      # @return [Integer] Strike offset (0 for ATM, positive for ATM+X, negative for ATM-X)
      def strike_offset
        return 0 if at_the_money?

        match = strike.match(/\AATM(\+|-)?(\d+)\z/)
        return 0 unless match

        sign = match[1] == "-" ? -1 : 1
        offset = match[2].to_i
        sign * offset
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
