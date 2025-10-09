# frozen_string_literal: true

require "dry/validation"

module DhanHQ
  module Contracts
    class OptionsBuyingAdvisorContract < Dry::Validation::Contract
      params do
        required(:meta).hash do
          required(:exchange_segment).filled(:string)
          required(:instrument).filled(:string)
          required(:security_id).filled(:string)
          optional(:symbol).maybe(:string)
          optional(:timestamp)
        end
        required(:spot).filled(:float)
        required(:indicators).hash
        optional(:option_chain).array(:hash)
        optional(:config).hash
      end
    end
  end
end
