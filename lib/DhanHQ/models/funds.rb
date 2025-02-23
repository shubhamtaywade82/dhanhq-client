# frozen_string_literal: true

module DhanHQ
  module Models
    class Funds < BaseModel
      HTTP_PATH = "/v2/fundlimit"

      attributes :availabel_balance, :sod_limit, :collateral_amount, :receiveable_amount, :utilized_amount,
                 :blocked_payout_amount, :withdrawable_balance
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
          fetch.availabel_balance
        end
      end
    end
  end
end
