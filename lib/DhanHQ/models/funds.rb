# frozen_string_literal: true

module DhanHQ
  module Models
    # Model representing the funds/limits endpoint response.
    class Funds < BaseModel
      # Base path used by the funds resource.
      HTTP_PATH = "/v2/fundlimit"

      attributes :available_balance, :sod_limit, :collateral_amount, :receiveable_amount, :utilized_amount,
                 :blocked_payout_amount, :withdrawable_balance

      # The API currently returns the key `availabelBalance` (note the typo).
      # To maintain backwards compatibility while exposing a correctly
      # spelled attribute, map the API response to `available_balance`.
      def assign_attributes
        if @attributes.key?(:availabel_balance) && !@attributes.key?(:available_balance)
          @attributes[:available_balance] = @attributes[:availabel_balance]
        end
        super
      end
      class << self
        ##
        # Provides a **shared instance** of the `Funds` resource.
        #
        # @return [DhanHQ::Resources::Funds]
        def resource
          @resource ||= DhanHQ::Resources::Funds.new
        end

        ##
        # Fetch fund details.
        #
        # @return [Fund]
        def fetch
          response = resource.fetch
          new(response, skip_validation: true)
        end

        ##
        # Fetch only the available balance.
        #
        # @return [Float] Available balance in the trading account.
        def balance
          fetch.available_balance
        end
      end
    end
  end
end
