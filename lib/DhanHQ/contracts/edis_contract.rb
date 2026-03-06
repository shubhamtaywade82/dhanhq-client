# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates requests for generating EDIS forms.
    class EdisFormContract < BaseContract
      params do
        required(:isin).filled(:string)
        required(:qty).filled(:integer, gt?: 0)
        required(:exchange).filled(:string, included_in?: %w[NSE BSE MCX ALL])
        required(:segment).filled(:string, included_in?: %w[EQ COMM FNO])
        required(:bulk).filled(:bool)
      end
    end

    # Validates requests for generating bulk EDIS forms.
    class EdisBulkFormContract < BaseContract
      params do
        required(:isin).array(:string)
        required(:exchange).filled(:string, included_in?: %w[NSE BSE MCX ALL])
        required(:segment).filled(:string, included_in?: %w[EQ COMM FNO])
      end
    end
  end
end
