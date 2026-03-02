# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests for P&L based exit configurations.
    class PnlBasedExitContract < BaseContract
      params do
        optional(:dhanClientId).maybe(:string)
        optional(:profitValue).maybe(:float, gt?: 0)
        optional(:lossValue).maybe(:float, gt?: 0)
        optional(:enableKillSwitch).maybe(:bool)
        optional(:productType).array(:string, included_in?: %w[INTRADAY DELIVERY])
      end

      rule(:profitValue, :lossValue) do
        key.failure("at least one of profitValue or lossValue must be provided") if !values[:profitValue] && !values[:lossValue]
      end
    end
  end
end
