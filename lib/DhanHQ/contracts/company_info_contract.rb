# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request for POST /v2/data/companyinfo (ScanX company fundamentals).
    #
    # securityId (digits), exchangeSegment (NSE_EQ/BSE_EQ), instrument (EQUITY),
    # metrics (one or more of CO / RATIOS / SHP).
    class CompanyInfoContract < BaseContract
      params do
        required(:security_id).filled(:string)
        required(:exchange_segment).filled(:string, included_in?: Constants::ScanX::COMPANY_INFO_SEGMENTS)
        required(:instrument).filled(:string, included_in?: Constants::ScanX::COMPANY_INFO_INSTRUMENTS)
        required(:metrics).filled(:array, min_size?: 1) do
          each(:str?, included_in?: Constants::ScanX::COMPANY_INFO_METRICS)
        end
      end

      rule(:security_id) do
        key.failure("must be a numeric security id string") unless value.to_s.match?(/\A\d+\z/)
      end
    end
  end
end
