# frozen_string_literal: true

require_relative "../contracts/option_chain_contract"

module DhanHQ
  module Models
    class OptionChain < BaseModel
      attr_reader :underlying_scrip, :underlying_seg, :expiry, :last_price, :option_data

      class << self
        def resource
          @resource ||= DhanHQ::Resources::OptionChain.new
        end

        # Fetch the entire option chain for an instrument
        #
        # @param params [Hash] The request parameters (snake_case format)
        # @return [HashWithIndifferentAccess] The filtered option chain data
        def fetch(params)
          validate_params!(params, DhanHQ::Contracts::OptionChainContract)

          response = resource.fetch(params)
          return {}.with_indifferent_access unless response[:status] == "success"

          filter_valid_strikes(response[:data]).with_indifferent_access
        end

        # Fetch the expiry list of an underlying security
        #
        # @param params [Hash] The request parameters (snake_case format)
        # @return [Array<String>] The list of expiry dates
        def fetch_expiry_list(params)
          response = resource.expirylist(params)
          response[:status] == "success" ? response[:data] : []
        end

        private

        # **Filters valid strikes where `ce` or `pe` has `last_price > 0` and converts strike prices to integers**
        #
        # @param data [Hash] The API response data
        # @return [Hash] The filtered option chain data with integer strike prices
        def filter_valid_strikes(data)
          return {} unless data.is_a?(Hash) && data.key?(:oc)

          filtered_oc = data[:oc].each_with_object({}) do |(strike_price, strike_data), result|
            ce_last_price = strike_data.dig("ce", "last_price").to_f
            pe_last_price = strike_data.dig("pe", "last_price").to_f

            # Only keep strikes where at least one of CE or PE has a valid last_price
            if ce_last_price.positive? || pe_last_price.positive?
              # Convert strike price to integer and store in result
              result[strike_price.to_f.to_i] = strike_data
            end
          end

          data.merge(oc: filtered_oc)
        end

        # Validation contract for option chain
        #
        # @return [DhanHQ::Contracts::OptionChainContract]
        def validation_contract
          DhanHQ::Contracts::OptionChainContract.new
        end
      end

      private

      # Validation contract for option chain
      #
      # @return [DhanHQ::Contracts::OptionChainContract]
      def validation_contract
        DhanHQ::Contracts::OptionChainContract.new
      end
    end
  end
end
