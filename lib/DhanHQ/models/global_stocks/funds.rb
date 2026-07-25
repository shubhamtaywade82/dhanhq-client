# frozen_string_literal: true

module DhanHQ
  module Models
    module GlobalStocks
      ##
      # USD fund limit for Global Stocks trading.
      #
      # This is a separate balance from the domestic INR limit exposed by
      # {DhanHQ::Models::Funds}.
      #
      # @example
      #   funds = DhanHQ::Models::GlobalStocks::Funds.fetch
      #   puts "Available: $#{funds.available_cash}"
      #   puts "Unsettled: $#{funds.unsettled_cash}"
      #
      class Funds < BaseModel
        HTTP_PATH = "/v2/globalstocks/fundlimit"

        attributes :dhan_client_id, :available_cash, :cash_on_account, :actual_cash,
                   :settled_cash, :unsettled_cash, :margin_utilized

        # Returns a concise prompt-friendly summary of the USD balance.
        def to_prompt
          parts = []
          parts << "available=$#{available_cash}" if available_cash
          parts << "settled=$#{settled_cash}" if settled_cash
          parts << "unsettled=$#{unsettled_cash}" if unsettled_cash
          parts << "utilized=$#{margin_utilized}" if margin_utilized&.positive?
          parts.join(", ")
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::Funds]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::Funds.new
          end

          # Fetches the Global Stocks fund limit.
          #
          # @return [Funds]
          def fetch
            new(resource.fetch, skip_validation: true)
          end

          # Convenience accessor for the available USD cash.
          #
          # @return [Float]
          def balance
            fetch.available_cash.to_f
          end
        end
      end
    end
  end
end
