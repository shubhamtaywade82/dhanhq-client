# frozen_string_literal: true

module DhanHQ
  module Jobs
    # Places a Dhan order via ActiveJob, without ever letting a queue adapter
    # (Sidekiq, Resque, ...) retry it.
    #
    # DhanHQ order writes are not idempotent -- a timed-out POST /v2/orders may
    # already have reached the exchange, so retrying it can place a duplicate
    # order (see the README's "Order Retries and Duplicate Protection"). Most
    # adapters retry unhandled exceptions at the backend level by default
    # (Sidekiq's own retry, independent of ActiveJob's opt-in `retry_on`), so
    # the only adapter-agnostic way to guarantee this write is never silently
    # retried is to make sure the exception never reaches the adapter at all.
    # `discard_on` does exactly that: it's handled inside ActiveJob's own
    # `execute`, so from the adapter's point of view the job completed, not
    # failed -- there is nothing left for the adapter's own retry logic to
    # act on.
    #
    # @example
    #   DhanHQ::Jobs::PlaceOrderJob.perform_later(
    #     transaction_type: DhanHQ::Constants::TransactionType::BUY,
    #     exchange_segment: DhanHQ::Constants::ExchangeSegment::NSE_EQ,
    #     product_type:     DhanHQ::Constants::ProductType::INTRADAY,
    #     order_type:       DhanHQ::Constants::OrderType::LIMIT,
    #     validity:         DhanHQ::Constants::Validity::DAY,
    #     security_id:      "11536",
    #     quantity:         5,
    #     price:            1500.0
    #   )
    class PlaceOrderJob < ActiveJob::Base
      discard_on DhanHQ::OrderError do |_job, error|
        DhanHQ.logger&.error("[DhanHQ::Jobs::PlaceOrderJob] order rejected: #{error.message}")
      end

      discard_on DhanHQ::RiskViolation do |_job, error|
        DhanHQ.logger&.warn("[DhanHQ::Jobs::PlaceOrderJob] risk check blocked the order: #{error.message}")
      end

      # @param params [Hash] Same params accepted by DhanHQ::Models::Order.place.
      # @return [DhanHQ::Models::Order]
      def perform(params)
        DhanHQ::Models::Order.place!(params)
      end
    end
  end
end
