# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request for POST /v2/data/newsheadline (ScanX live news).
    #
    # categories[] (ALL or any news category), limit (1-50), optional universe
    # (PORTFOLIO / WATCHLIST) and stock_list[] of security ids. dhanClientId is
    # injected by the client layer and is not validated here.
    class NewsHeadlineContract < BaseContract
      params do
        required(:categories).filled(:array, min_size?: 1) do
          each(:str?, included_in?: Constants::ScanX::NEWS_CATEGORIES)
        end
        required(:limit).filled(:integer, included_in?: 1..50)
        optional(:universe).filled(:string, included_in?: Constants::ScanX::NEWS_UNIVERSES)
        optional(:stock_list).filled(:array) { each(:str?) }
      end
    end
  end
end
