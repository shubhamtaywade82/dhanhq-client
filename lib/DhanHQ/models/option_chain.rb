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
    #   nifty_first_strike = chain[:strikes].first
    #   puts "Strike: #{nifty_first_strike[:strike]}"
    #   puts "Call LTP: ₹#{nifty_first_strike[:call][:last_price]}"
    #
    # @example Fetch expiry list for an underlying
    #   expiries = DhanHQ::Models::OptionChain.expiry_list(
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
    #   strike_data = chain[:strikes].find { |s| s[:strike] == 25000.0 }
    #   ce_greeks = strike_data[:call][:greeks]
    #   puts "Delta: #{ce_greeks[:delta]}"
    #
    class OptionChain < BaseModel
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
        #   @option params [Integer] :underlying_scrip (required) Security ID of the underlying instrument.
        #   @option params [String] :underlying_seg (required) Exchange and segment of underlying.
        #   @option params [String] :expiry (required) Expiry date in "YYYY-MM-DD" format.
        #
        # @return [HashWithIndifferentAccess] Normalized option chain data.
        #   Response structure:
        #   - **:last_price** [Float] Last Traded Price (LTP) of the underlying instrument
        #   - **:strikes** [Array<Hash>] Sorted array of strike data:
        #     - **:strike** [Float] The strike price
        #     - **:call** [Hash] Call Option (CE) data for this strike
        #     - **:put** [Hash] Put Option (PE) data for this strike
        #
        # @raise [DhanHQ::ValidationError] If validation fails for any parameter
        def fetch(params)
          validate_params!(params, DhanHQ::Contracts::OptionChainContract)

          response = resource.fetch(params)
          return {}.with_indifferent_access unless response[:status] == "success"

          normalize_chain(response[:data]).with_indifferent_access
        end

        ##
        # Fetches the list of active expiry dates for an underlying instrument.
        #
        # @param params [Hash{Symbol => Integer, String}] Request parameters for expiry list
        #   @option params [Integer] :underlying_scrip (required) Security ID of the underlying instrument.
        #   @option params [String] :underlying_seg (required) Exchange and segment of underlying.
        #
        # @return [Array<String>] Array of expiry dates in "YYYY-MM-DD" format.
        def fetch_expiry_list(params)
          validate_params!(params, DhanHQ::Contracts::OptionChainExpiryListContract)

          response = resource.expirylist(params)
          response[:status] == "success" ? response[:data] : []
        end

        alias expiry_list fetch_expiry_list

        private

        ##
        # Normalizes the raw API option chain data.
        # - Converts strike keys to numeric
        # - Renames 'ce' to 'call' and 'pe' to 'put'
        # - Filters strikes with zero prices
        # - Sorts strikes ascending
        #
        # @param data [Hash] The raw API response data
        # @return [Hash] Normalized option chain
        def normalize_chain(data)
          return {} unless data.is_a?(Hash) && data.key?(:oc)

          strikes = data[:oc].map do |strike_price, strike_data|
            ce = strike_data["ce"] || strike_data[:ce]
            pe = strike_data["pe"] || strike_data[:pe]

            next if ce.dig("last_price").to_f.zero? && pe.dig("last_price").to_f.zero?

            {
              strike: strike_price.to_f,
              call: ce,
              put: pe
            }
          end.compact

          {
            last_price: data[:last_price],
            strikes: strikes.sort_by { |s| s[:strike] }
          }
        end
      end
    end
  end
end
