# frozen_string_literal: true

module DhanHQ
  module Contracts
    class OptionChainContract < Dry::Validation::Contract
      params do
        required(:UnderlyingScrip).filled(:integer)
        required(:UnderlyingSeg).filled(:string, included_in?: %w[NSE_EQ NSE_FNO BSE_EQ IDX_I])
        required(:Expiry).filled(:string, format?: /\d{4}-\d{2}-\d{2}/)
      end
    end
  end
end
