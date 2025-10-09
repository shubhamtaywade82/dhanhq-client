# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates the exchange segment param for instrument list endpoint
    class InstrumentListContract < BaseContract
      params do
        required(:exchange_segment).filled(:string, included_in?: EXCHANGE_SEGMENTS)
      end
    end
  end
end
