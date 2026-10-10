# frozen_string_literal: true

module DhanHQ
  module Contracts
    # Validates request for POST /v2/data/technical (ScanX technical indicators).
    #
    # securityId (digits), exchangeSegment (NSE_EQ/IDX_I), instrument
    # (INDEX/EQUITY), timeframe (1/5/15/D), indicators[] (e.g. SMA_20, RSI_14).
    class TechnicalDataContract < BaseContract
      params do
        required(:security_id).filled(:string)
        required(:exchange_segment).filled(:string, included_in?: Constants::ScanX::TECHNICAL_SEGMENTS)
        required(:instrument).filled(:string, included_in?: Constants::ScanX::TECHNICAL_INSTRUMENTS)
        required(:timeframe).filled(:string, included_in?: Constants::ScanX::TECHNICAL_TIMEFRAMES)
        required(:indicators).filled(:array, min_size?: 1) do
          each(:str?, included_in?: Constants::ScanX::TECHNICAL_INDICATORS)
        end
      end

      rule(:security_id) do
        key.failure("must be a numeric security id string") unless value.to_s.match?(/\A\d+\z/)
      end
    end
  end
end
