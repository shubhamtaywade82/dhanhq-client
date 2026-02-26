# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests for configuring static IP addresses.
    class UserIpContract < BaseContract
      params do
        optional(:dhanClientId).maybe(:string)
        required(:ip).filled(:string)
        required(:ipFlag).filled(:string, included_in?: %w[PRIMARY SECONDARY])
      end
    end
  end
end
