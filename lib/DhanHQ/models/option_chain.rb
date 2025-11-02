# frozen_string_literal: true

require_relative "../contracts/option_chain_contract"

module DhanHQ
  module Models
    ##
    # Model for fetching option chain data for any option instrument across exchanges.
    #
    # The Option Chain API provides the entire option chain for any underlying instrument
    # across NSE, BSE, and MCX exchanges. For each strike price, you get Open Interest (OI),
    # Greeks (Delta, Theta, Gamma, Vega), Volume, Last Traded Price, Best Bid/Ask prices,
    # Implied Volatility (IV), and other option analytics.
    #
    # @note **Rate Limits**: You can call the Option Chain API once every 3 seconds.
    #   This rate limit is enforced because OI data updates slowly compared to LTP or
    #   other data parameters. The client's internal rate limiter automatically throttles
    #   calls to prevent exceeding limits.
    #
    # @note **Data Filtering**: The model automatically filters out strikes where both
    #   Call (CE) and Put (PE) options have zero `last_price`, keeping the payload compact
    #   and focused on actively traded strikes.
    #
    # @example Fetch option chain for NIFTY index options
    #   chain = DhanHQ::Models::OptionChain.fetch(
    #     underlying_scrip: 13,
    #     underlying_seg: "IDX_I",
    #     expiry: "2024-10-31"
    #   )
    #   puts "Underlying LTP: ₹#{chain[:last_price]}"
    #   nifty_25000 = chain[:oc]["25000.000000"]
    #   puts "CE LTP: ₹#{nifty_25000['ce'][:last_price]}"
    #   puts "CE OI: #{nifty_25000['ce'][:oi]}"
    #
    # @example Fetch expiry list for an underlying
    #   expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
    #     underlying_scrip: 13,
    #     underlying_seg: "IDX_I"
    #   )
    #   expiries.each { |expiry| puts expiry }
    #
    # @example Access Greeks for a strike
    #   chain = DhanHQ::Models::OptionChain.fetch(
    #     underlying_scrip: 1333,
    #     underlying_seg: "NSE_FNO",
    #     expiry: "2024-12-26"
    #   )
    #   strike_data = chain[:oc]["25000.000000"]
    #   ce_greeks = strike_data['ce'][:greeks]
    #   puts "Delta: #{ce_greeks[:delta]}"
    #   puts "Gamma: #{ce_greeks[:gamma]}"
    #   puts "Theta: #{ce_greeks[:theta]}"
    #   puts "Vega: #{ce_greeks[:vega]}"
    #
    class OptionChain < BaseModel
      attr_reader :underlying_scrip, :underlying_seg, :expiry, :last_price, :option_data

      class << self
        ##
        # Provides a shared instance of the OptionChain resource.
        #
        # @return [DhanHQ::Resources::OptionChain] The OptionChain resource client instance
        def resource
          @resource ||= DhanHQ::Resources::OptionChain.new
        end

        ##
        # Fetches the entire option chain for a specified underlying instrument and expiry.
        #
        # Retrieves real-time option chain data across all strikes for the given underlying.
        # The response includes Open Interest (OI), Greeks, Volume, Last Traded Price,
        # Best Bid/Ask prices, Implied Volatility (IV), and other option analytics for
        # both Call (CE) and Put (PE) options at each strike price.
        #
        # @param params [Hash{Symbol => Integer, String}] Request parameters for option chain
        #   @option params [Integer] :underlying_scrip (required) Security ID of the underlying
        #     instrument. Can be found via the Instruments API.
        #   @option params [String] :underlying_seg (required) Exchange and segment of underlying
        #     for which data is to be fetched.
        #     Valid values: "IDX_I" (Index), "NSE_FNO" (NSE F&O), "BSE_FNO" (BSE F&O), "MCX_FO" (MCX)
        #   @option params [String] :expiry (required) Expiry date of the option contract for
        #     which the option chain is requested. Must be in "YYYY-MM-DD" format.
        #     List of active expiries can be fetched using {fetch_expiry_list}.
        #
        # @return [HashWithIndifferentAccess] Filtered option chain data.
        #   Response structure:
        #   - **:last_price** [Float] Last Traded Price (LTP) of the underlying instrument
        #   - **:oc** [Hash{String => Hash}] Option chain data organized by strike price.
        #     Strike prices are stored as string keys (e.g., "25000.000000").
        #     Each strike contains:
        #     - **"ce"** [Hash{Symbol => Float, Integer, Hash}] Call Option data for this strike:
        #       - **:greeks** [Hash{Symbol => Float}] Option Greeks:
        #         - **:delta** [Float] Measures the change of option's premium based on
        #           every 1 rupee change in underlying
        #         - **:theta** [Float] Measures how quickly an option's value decreases over time
        #         - **:gamma** [Float] Rate of change in an option's delta in relation to the
        #           price of the underlying asset
        #         - **:vega** [Float] Measures the change of option's premium in response to
        #           a 1% change in implied volatility
        #       - **:implied_volatility** [Float] Value of expected volatility of a stock
        #         over the life of the option
        #       - **:last_price** [Float] Last Traded Price of the Call Option Instrument
        #       - **:oi** [Integer] Open Interest of the Call Option Instrument
        #       - **:previous_close_price** [Float] Previous day close price
        #       - **:previous_oi** [Integer] Previous day Open Interest
        #       - **:previous_volume** [Integer] Previous day volume
        #       - **:top_ask_price** [Float] Current best ask price available
        #       - **:top_ask_quantity** [Integer] Quantity available at current best ask price
        #       - **:top_bid_price** [Float] Current best bid price available
        #       - **:top_bid_quantity** [Integer] Quantity available at current best bid price
        #       - **:volume** [Integer] Day volume for Call Option Instrument
        #     - **"pe"** [Hash{Symbol => Float, Integer, Hash}] Put Option data for this strike.
        #       Contains the same fields as "ce" (Call Option data).
        #
        # @note Strikes where both CE and PE have zero `last_price` are automatically filtered out.
        #   This keeps the payload compact and focused on actively traded strikes.
        #
        # @example Fetch option chain for NIFTY index options
        #   chain = DhanHQ::Models::OptionChain.fetch(
        #     underlying_scrip: 13,
        #     underlying_seg: "IDX_I",
        #     expiry: "2024-10-31"
        #   )
        #   puts "NIFTY LTP: ₹#{chain[:last_price]}"
        #
        # @example Access Call and Put data for a specific strike
        #   chain = DhanHQ::Models::OptionChain.fetch(
        #     underlying_scrip: 13,
        #     underlying_seg: "IDX_I",
        #     expiry: "2024-10-31"
        #   )
        #   strike_25000 = chain[:oc]["25000.000000"]
        #   ce_data = strike_25000["ce"]
        #   pe_data = strike_25000["pe"]
        #   puts "CE LTP: ₹#{ce_data[:last_price]}, OI: #{ce_data[:oi]}"
        #   puts "PE LTP: ₹#{pe_data[:last_price]}, OI: #{pe_data[:oi]}"
        #
        # @example Calculate OI change and analyze Greeks
        #   chain = DhanHQ::Models::OptionChain.fetch(
        #     underlying_scrip: 1333,
        #     underlying_seg: "NSE_FNO",
        #     expiry: "2024-12-26"
        #   )
        #   strike_data = chain[:oc]["25000.000000"]
        #   ce = strike_data["ce"]
        #   oi_change = ce[:oi] - ce[:previous_oi]
        #   puts "OI Change: #{oi_change}"
        #   puts "Delta: #{ce[:greeks][:delta]}"
        #   puts "IV: #{ce[:implied_volatility]}%"
        #
        # @raise [DhanHQ::ValidationError] If validation fails for any parameter or date format
        def fetch(params)
          validate_params!(params, DhanHQ::Contracts::OptionChainContract)

          response = resource.fetch(params)
          return {}.with_indifferent_access unless response[:status] == "success"

          filter_valid_strikes(response[:data]).with_indifferent_access
        end

        ##
        # Fetches the list of active expiry dates for an underlying instrument.
        #
        # Retrieves all expiry dates for which option instruments are active for the given
        # underlying. This list is useful for selecting valid expiry dates when fetching
        # option chains.
        #
        # @param params [Hash{Symbol => Integer, String}] Request parameters for expiry list
        #   @option params [Integer] :underlying_scrip (required) Security ID of the underlying
        #     instrument. Can be found via the Instruments API.
        #   @option params [String] :underlying_seg (required) Exchange and segment of underlying
        #     for which expiry list is to be fetched.
        #     Valid values: "IDX_I" (Index), "NSE_FNO" (NSE F&O), "BSE_FNO" (BSE F&O), "MCX_FO" (MCX)
        #
        # @return [Array<String>] Array of expiry dates in "YYYY-MM-DD" format.
        #   Returns empty array if the API response status is not "success" or if no expiries are found.
        #
        # @example Fetch expiry list for NIFTY index
        #   expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
        #     underlying_scrip: 13,
        #     underlying_seg: "IDX_I"
        #   )
        #   puts "Available expiries:"
        #   expiries.each { |expiry| puts "  #{expiry}" }
        #
        # @example Use expiry list to fetch option chains
        #   expiries = DhanHQ::Models::OptionChain.fetch_expiry_list(
        #     underlying_scrip: 1333,
        #     underlying_seg: "NSE_FNO"
        #   )
        #   nearest_expiry = expiries.first
        #   chain = DhanHQ::Models::OptionChain.fetch(
        #     underlying_scrip: 1333,
        #     underlying_seg: "NSE_FNO",
        #     expiry: nearest_expiry
        #   )
        #
        # @raise [DhanHQ::ValidationError] If validation fails for any parameter
        def fetch_expiry_list(params)
          validate_params!(params, DhanHQ::Contracts::OptionChainExpiryListContract)

          response = resource.expirylist(params)
          response[:status] == "success" ? response[:data] : []
        end

        private

        ##
        # Filters valid strikes where at least one of CE or PE has a non-zero last_price.
        #
        # Removes strikes from the option chain where both Call (CE) and Put (PE) options
        # have zero `last_price`, keeping only actively traded strikes. This keeps the
        # payload compact and focused on relevant data.
        #
        # @param data [Hash] The API response data containing option chain information
        # @return [Hash] The filtered option chain data with original strike price keys preserved
        #
        # @api private
        def filter_valid_strikes(data)
          return {} unless data.is_a?(Hash) && data.key?(:oc)

          filtered_oc = data[:oc].each_with_object({}) do |(strike_price, strike_data), result|
            ce_last_price = strike_data.dig("ce", "last_price").to_f
            pe_last_price = strike_data.dig("pe", "last_price").to_f

            # Only keep strikes where at least one of CE or PE has a valid last_price
            result[strike_price] = strike_data if ce_last_price.positive? || pe_last_price.positive?
          end

          data.merge(oc: filtered_oc)
        end

        # Validation contract for option chain
        #
        # @return [DhanHQ::Contracts::OptionChainContract]
        # @api private
        def validation_contract
          DhanHQ::Contracts::OptionChainContract.new
        end
      end

      private

      # Validation contract for option chain
      #
      # @return [DhanHQ::Contracts::OptionChainContract]
      # @api private
      def validation_contract
        DhanHQ::Contracts::OptionChainContract.new
      end
    end
  end
end
