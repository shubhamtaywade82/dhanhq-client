# frozen_string_literal: true

module DhanHQ
  module Models
    module GlobalStocks
      ##
      # Current US market session status.
      #
      # @example Gate a strategy on the US session
      #   status = DhanHQ::Models::GlobalStocks::MarketStatus.fetch
      #   return unless status.open?
      #
      class MarketStatus < BaseModel
        HTTP_PATH = "/v2/globalstocks/marketstatus"

        attributes :status, :market_open_time, :market_close_time, :holiday_flag

        # Returns a concise prompt-friendly summary of the session.
        def to_prompt
          parts = ["US market #{status}"]
          parts << "open=#{market_open_time}" if market_open_time
          parts << "close=#{market_close_time}" if market_close_time
          parts << "holiday" if holiday?
          parts.join(", ")
        end

        # @return [Boolean] True when the US market is currently open.
        def open?
          status.to_s.casecmp(DhanHQ::Constants::GlobalStocks::MarketStatus::OPEN).zero?
        end

        # @return [Boolean] True when the US market is currently closed.
        def closed?
          !open?
        end

        # @return [Boolean] True when today is a US market holiday.
        def holiday?
          holiday_flag == true
        end

        class << self
          # @return [DhanHQ::Resources::GlobalStocks::MarketStatus]
          def resource
            @resource ||= DhanHQ::Resources::GlobalStocks::MarketStatus.new
          end

          # Fetches the current US market status.
          #
          # @return [MarketStatus]
          def fetch
            new(resource.fetch, skip_validation: true)
          end

          # @return [Boolean] True when the US market is currently open.
          def open?
            fetch.open?
          end
        end
      end
    end
  end
end
