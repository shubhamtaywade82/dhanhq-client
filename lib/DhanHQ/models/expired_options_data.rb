# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Model for fetching expired options contract data on a rolling basis.
    #
    # This API provides pre-processed expired options data for up to the last 5 years.
    # Data is available on a minute-level basis, organized by strike price relative to spot
    # (e.g., ATM, ATM+1, ATM-1, etc.). You can fetch up to 31 days of data in a single API call.
    #
    # Available data includes:
    # - OHLC (Open, High, Low, Close) prices
    # - Volume and Open Interest
    # - Implied Volatility (IV)
    # - Strike prices
    # - Spot prices
    # - Timestamps
    #
    # Strike ranges:
    # - Index Options (near expiry): Up to ATM+10 / ATM-10
    # - All other contracts: Up to ATM+3 / ATM-3
    #
    # @example Fetch expired options data for NIFTY
    #   data = DhanHQ::Models::ExpiredOptionsData.fetch(
    #     exchange_segment: "NSE_FNO",
    #     interval: "1",
    #     security_id: 13,
    #     instrument: "OPTIDX",
    #     expiry_flag: "MONTH",
    #     expiry_code: 1,
    #     strike: "ATM",
    #     drv_option_type: "CALL",
    #     required_data: ["open", "high", "low", "close", "volume"],
    #     from_date: "2021-08-01",
    #     to_date: "2021-09-01"
    #   )
    #   ohlc = data.ohlc_data
    #   volumes = data.volume_data
    #
    # @example Access call option data
    #   call_data = data.call_data
    #   put_data = data.put_data
    #
    class ExpiredOptionsData < BaseModel
      # All expired options data attributes
      attributes :exchange_segment, :interval, :security_id, :instrument,
                 :expiry_flag, :expiry_code, :strike, :drv_option_type,
                 :required_data, :from_date, :to_date, :data

      class << self
        ##
        # Fetches expired options data for rolling contracts on a minute-level basis.
        #
        # Data is organized by strike price relative to spot and can be fetched for up to
        # 31 days in a single request. Historical data is available for up to the last 5 years.
        #
        # @param params [Hash{Symbol => String, Integer, Array<String>}] Request parameters
        #   @option params [String] :exchange_segment (required) Exchange and segment identifier.
        #     Valid values: "NSE_FNO", "BSE_FNO", "NSE_EQ", "BSE_EQ"
        #   @option params [String] :interval (required) Minute intervals for the timeframe.
        #     Valid values: "1", "5", "15", "25", "60"
        #   @option params [Integer] :security_id (required) Underlying exchange standard ID for each scrip
        #   @option params [String] :instrument (required) Instrument type of the scrip.
        #     Valid values: "OPTIDX" (Index Options), "OPTSTK" (Stock Options)
        #   @option params [String] :expiry_flag (required) Expiry interval of the instrument.
        #     Valid values: "WEEK", "MONTH"
        #   @option params [Integer] :expiry_code (required) Expiry code for the instrument
        #   @option params [String] :strike (required) Strike price specification.
        #     Format: "ATM" for At The Money, "ATM+X" or "ATM-X" for offset strikes.
        #     For Index Options (near expiry): Up to ATM+10 / ATM-10
        #     For all other contracts: Up to ATM+3 / ATM-3
        #   @option params [String] :drv_option_type (required) Option type.
        #     Valid values: "CALL", "PUT"
        #   @option params [Array<String>] :required_data (required) Array of required data fields.
        #     Valid values: "open", "high", "low", "close", "iv", "volume", "strike", "oi", "spot"
        #   @option params [String] :from_date (required) Start date of the desired range in YYYY-MM-DD format.
        #     Cannot be more than 5 years ago. Same-day ranges are allowed.
        #   @option params [String] :to_date (required) End date of the desired range (non-inclusive) in YYYY-MM-DD format.
        #     Date range cannot exceed 31 days from from_date (to_date is non-inclusive). Same-day `from_date`/`to_date` is valid.
        #
        # @return [ExpiredOptionsData] Expired options data object with fetched data
        #
        # @example Fetch NIFTY index options data
        #   data = DhanHQ::Models::ExpiredOptionsData.fetch(
        #     exchange_segment: "NSE_FNO",
        #     interval: "1",
        #     security_id: 13,
        #     instrument: "OPTIDX",
        #     expiry_flag: "MONTH",
        #     expiry_code: 1,
        #     strike: "ATM",
        #     drv_option_type: "CALL",
        #     required_data: ["open", "high", "low", "close", "volume", "iv", "oi", "spot"],
        #     from_date: "2021-08-01",
        #     to_date: "2021-09-01"
        #   )
        #
        # @example Fetch stock options data for ATM+2 strike
        #   data = DhanHQ::Models::ExpiredOptionsData.fetch(
        #     exchange_segment: "NSE_FNO",
        #     interval: "15",
        #     security_id: 11536,
        #     instrument: "OPTSTK",
        #     expiry_flag: "WEEK",
        #     expiry_code: 0,
        #     strike: "ATM+2",
        #     drv_option_type: "PUT",
        #     required_data: ["open", "high", "low", "close", "volume"],
        #     from_date: "2024-01-01",
        #     to_date: "2024-01-31"
        #   )
        #
        # @raise [DhanHQ::ValidationError] If validation fails for any parameter
        def fetch(params)
          normalized = normalize_params(params)
          validate_params(normalized)

          response = expired_options_resource.fetch(normalized)
          new(response.merge(normalized), skip_validation: true)
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

        # Best-effort normalization: coerce convertible values into expected shapes.
        # Only values that are not convertible will fail validation.
        def normalize_params(params)
          normalized = params.dup

          # interval: accept Integer or String, normalize to String
          normalized[:interval] = normalized[:interval].to_s if normalized.key?(:interval)

          # security_id, expiry_code: accept String or Integer, normalize to Integer if possible
          if normalized.key?(:security_id)
            original = normalized[:security_id]
            converted = Integer(original, exception: false)
            normalized[:security_id] = converted || original
          end

          if normalized.key?(:expiry_code)
            original = normalized[:expiry_code]
            converted = Integer(original, exception: false)
            normalized[:expiry_code] = converted || original
          end

          # Uppercase enums where appropriate
          %i[exchange_segment instrument expiry_flag drv_option_type].each do |k|
            next unless normalized.key?(k)

            v = normalized[k]
            normalized[k] = v.to_s.upcase
          end

          # required_data: array of strings, downcased unique
          if normalized.key?(:required_data)
            normalized[:required_data] = Array(normalized[:required_data]).map { |x| x.to_s.downcase }.uniq
          end

          # strike: ensure string
          normalized[:strike] = normalized[:strike].to_s.upcase if normalized.key?(:strike)

          # dates: ensure string (contract validates format)
          normalized[:from_date] = normalized[:from_date].to_s if normalized.key?(:from_date)
          normalized[:to_date] = normalized[:to_date].to_s if normalized.key?(:to_date)

          normalized
        end
      end

      ##
      # ExpiredOptionsData objects are read-only, so no validation contract needed
      def validation_contract
        nil
      end

      ##
      # Gets call option data from the response.
      #
      # @return [Hash{Symbol => Array<Float, Integer>}, nil] Call option data hash containing arrays
      #   of OHLC, volume, IV, OI, strike, spot, and timestamps. Returns nil if call option data
      #   is not available in the response. Keys are normalized to snake_case:
      #   - **:open** [Array<Float>] Open prices
      #   - **:high** [Array<Float>] High prices
      #   - **:low** [Array<Float>] Low prices
      #   - **:close** [Array<Float>] Close prices
      #   - **:volume** [Array<Integer>] Volume traded
      #   - **:iv** [Array<Float>] Implied volatility values
      #   - **:oi** [Array<Float>] Open interest values
      #   - **:strike** [Array<Float>] Strike prices
      #   - **:spot** [Array<Float>] Spot prices
      #   - **:timestamp** [Array<Integer>] Epoch timestamps
      def call_data
        return nil unless data.is_a?(Hash)

        data["ce"] || data[:ce]
      end

      ##
      # Gets put option data from the response.
      #
      # @return [Hash{Symbol => Array<Float, Integer>}, nil] Put option data hash containing arrays
      #   of OHLC, volume, IV, OI, strike, spot, and timestamps. Returns nil if put option data
      #   is not available in the response. Keys are normalized to snake_case:
      #   - **:open** [Array<Float>] Open prices
      #   - **:high** [Array<Float>] High prices
      #   - **:low** [Array<Float>] Low prices
      #   - **:close** [Array<Float>] Close prices
      #   - **:volume** [Array<Integer>] Volume traded
      #   - **:iv** [Array<Float>] Implied volatility values
      #   - **:oi** [Array<Float>] Open interest values
      #   - **:strike** [Array<Float>] Strike prices
      #   - **:spot** [Array<Float>] Spot prices
      #   - **:timestamp** [Array<Integer>] Epoch timestamps
      def put_data
        return nil unless data.is_a?(Hash)

        data["pe"] || data[:pe]
      end

      ##
      # Gets data for the specified option type.
      #
      # @param option_type [String] Option type to retrieve. Valid values: "CALL", "PUT"
      # @return [Hash{Symbol => Array<Float, Integer>}, nil] Option data hash or nil if not available.
      #   See {#call_data} or {#put_data} for structure details.
      def data_for_type(option_type)
        case option_type.upcase
        when DhanHQ::Constants::OptionType::CALL
          call_data
        when DhanHQ::Constants::OptionType::PUT
          put_data
        end
      end

      ##
      # Gets OHLC (Open, High, Low, Close) data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Hash{Symbol => Array<Float>}] OHLC data hash with:
      #   - **:open** [Array<Float>] Open prices for each time point
      #   - **:high** [Array<Float>] High prices for each time point
      #   - **:low** [Array<Float>] Low prices for each time point
      #   - **:close** [Array<Float>] Close prices for each time point
      # @return [Hash{Symbol => Array}] Empty hash if option data is not available
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

      ##
      # Gets volume data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Integer>] Array of volume values traded in each timeframe.
      #   Returns empty array if option data is not available or volume was not requested.
      def volume_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["volume"] || option_data[:volume] || []
      end

      ##
      # Gets open interest (OI) data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Float>] Array of open interest values for each timeframe.
      #   Returns empty array if option data is not available or OI was not requested.
      def open_interest_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["oi"] || option_data[:oi] || []
      end

      ##
      # Gets implied volatility (IV) data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Float>] Array of implied volatility values for each timeframe.
      #   Returns empty array if option data is not available or IV was not requested.
      def implied_volatility_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["iv"] || option_data[:iv] || []
      end

      ##
      # Gets strike price data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Float>] Array of strike prices for each timeframe.
      #   Returns empty array if option data is not available or strike was not requested.
      def strike_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["strike"] || option_data[:strike] || []
      end

      ##
      # Gets spot price data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Float>] Array of spot prices for each timeframe.
      #   Returns empty array if option data is not available or spot was not requested.
      def spot_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["spot"] || option_data[:spot] || []
      end

      ##
      # Gets timestamp data for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Integer>] Array of epoch timestamps (Unix time in seconds) for each timeframe.
      #   Returns empty array if option data is not available.
      def timestamp_data(option_type = nil)
        option_type ||= drv_option_type
        option_data = data_for_type(option_type)
        return [] unless option_data

        option_data["timestamp"] || option_data[:timestamp] || []
      end

      ##
      # Gets the number of data points available for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Integer] Number of data points (timeframes) available. Returns 0 if no data.
      def data_points_count(option_type = nil)
        timestamps = timestamp_data(option_type)
        timestamps.size
      end

      ##
      # Calculates the average volume for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Float] Average volume across all timeframes. Returns 0.0 if no volume data is available.
      def average_volume(option_type = nil)
        volumes = volume_data(option_type)
        return 0.0 if volumes.empty?

        volumes.sum.to_f / volumes.size
      end

      ##
      # Calculates the average open interest for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Float] Average open interest across all timeframes. Returns 0.0 if no OI data is available.
      def average_open_interest(option_type = nil)
        oi_data = open_interest_data(option_type)
        return 0.0 if oi_data.empty?

        oi_data.sum.to_f / oi_data.size
      end

      ##
      # Calculates the average implied volatility for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Float] Average implied volatility across all timeframes. Returns 0.0 if no IV data is available.
      def average_implied_volatility(option_type = nil)
        iv_data = implied_volatility_data(option_type)
        return 0.0 if iv_data.empty?

        iv_data.sum.to_f / iv_data.size
      end

      ##
      # Calculates price range (high - low) for each timeframe of the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Array<Float>] Array of price ranges (high - low) for each data point.
      #   Returns empty array if OHLC data is not available.
      def price_ranges(option_type = nil)
        ohlc = ohlc_data(option_type)
        highs = ohlc[:high]
        lows = ohlc[:low]

        return [] if highs.empty? || lows.empty?

        highs.zip(lows).map { |high, low| high - low }
      end

      ##
      # Gets comprehensive summary statistics for the specified option type.
      #
      # @param option_type [String, nil] Option type to retrieve ("CALL" or "PUT").
      #   If nil, uses the {#drv_option_type} from the request.
      # @return [Hash{Symbol => Integer, Float, Array, Boolean}] Summary statistics hash containing:
      #   - **:data_points** [Integer] Total number of data points
      #   - **:avg_volume** [Float] Average volume
      #   - **:avg_open_interest** [Float] Average open interest
      #   - **:avg_implied_volatility** [Float] Average implied volatility
      #   - **:price_ranges** [Array<Float>] Price ranges (high - low) for each point
      #   - **:has_ohlc** [Boolean] Whether OHLC data is available
      #   - **:has_volume** [Boolean] Whether volume data is available
      #   - **:has_open_interest** [Boolean] Whether open interest data is available
      #   - **:has_implied_volatility** [Boolean] Whether implied volatility data is available
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

      ##
      # Checks if this is index options data.
      #
      # @return [Boolean] true if instrument type is "OPTIDX", false otherwise
      def index_options?
        instrument == DhanHQ::Constants::InstrumentType::OPTIDX
      end

      ##
      # Checks if this is stock options data.
      #
      # @return [Boolean] true if instrument type is "OPTSTK", false otherwise
      def stock_options?
        instrument == DhanHQ::Constants::InstrumentType::OPTSTK
      end

      ##
      # Checks if this is weekly expiry data.
      #
      # @return [Boolean] true if expiry_flag is "WEEK", false otherwise
      def weekly_expiry?
        expiry_flag == "WEEK"
      end

      ##
      # Checks if this is monthly expiry data.
      #
      # @return [Boolean] true if expiry_flag is "MONTH", false otherwise
      def monthly_expiry?
        expiry_flag == "MONTH"
      end

      ##
      # Checks if this is call option data.
      #
      # @return [Boolean] true if drv_option_type is "CALL", false otherwise
      def call_option?
        drv_option_type == DhanHQ::Constants::OptionType::CALL
      end

      ##
      # Checks if this is put option data.
      #
      # @return [Boolean] true if drv_option_type is "PUT", false otherwise
      def put_option?
        drv_option_type == DhanHQ::Constants::OptionType::PUT
      end

      ##
      # Checks if the strike is at the money (ATM).
      #
      # @return [Boolean] true if strike is "ATM", false otherwise
      def at_the_money?
        strike == "ATM"
      end

      ##
      # Calculates the strike offset from ATM (At The Money).
      #
      # @return [Integer] Strike offset value:
      #   - 0 for ATM strikes
      #   - Positive integer for ATM+X (e.g., ATM+3 returns 3)
      #   - Negative integer for ATM-X (e.g., ATM-2 returns -2)
      #   - 0 if strike format is invalid
      #
      # @example
      #   data.strike = "ATM+5"
      #   data.strike_offset # => 5
      #
      #   data.strike = "ATM-3"
      #   data.strike_offset # => -3
      #
      #   data.strike = "ATM"
      #   data.strike_offset # => 0
      def strike_offset
        return 0 if at_the_money?

        match = strike.match(/\AATM(\+|-)?(\d+)\z/)
        return 0 unless match

        sign = match[1] == "-" ? -1 : 1
        offset = match[2].to_i
        sign * offset
      end
    end
  end
end
