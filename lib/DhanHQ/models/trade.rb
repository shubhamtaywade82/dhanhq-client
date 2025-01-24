# frozen_string_literal: true

module DhanHQ
  module Models
    class Trade < BaseResource
      private

      # Validation contract for the Trade model
      def validation_contract
        nil # Trades may not require validation, as they are typically read-only
      end
    end
  end
end
