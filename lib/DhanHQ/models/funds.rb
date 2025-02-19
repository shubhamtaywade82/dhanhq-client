# frozen_string_literal: true

module DhanHQ
  module Models
    class Funds < BaseModel
      HTTP_PATH = "/v2/fundlimit"

      attributes :availabel_balance, :sod_limit, :collateral_amount, :receiveable_amount, :utilized_amount, :blocked_payout_amount, :withdrawable_balance
      class << self
        def balance
          response = api.get(resource_path.to_s)

          build_from_response(response)
        end
      end
    end
  end
end
