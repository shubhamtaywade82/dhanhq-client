# frozen_string_literal: true

require "securerandom"
require "active_support/core_ext/hash/indifferent_access"

module DhanHQ
  module DryRun
    # Answers state-changing requests locally instead of sending them.
    #
    # Reads still go to the API, so market data, the option chain, positions and
    # holdings stay live and a strategy can be rehearsed against real prices. The one
    # exception is a read for an order this simulator itself invented: those carry the
    # {ID_PREFIX} sentinel, can only exist because of a dry run, and are replayed from
    # the {Ledger} so the models' place-then-refetch flow completes without touching
    # the network.
    #
    # Responses are shaped per endpoint family, because callers inspect them: order
    # placements need an `orderId` for the models to treat the write as successful, and
    # the basket endpoint needs an `orders` array or {DhanHQ::Models::MultiOrder} sees
    # a failure.
    class Simulator
      # Marks an order id as fabricated by a dry run.
      ID_PREFIX = "DRYRUN-"

      # Extracts a fabricated id out of a request path.
      ID_PATTERN = /#{Regexp.escape(ID_PREFIX)}[A-Za-z0-9]+/

      def initialize(ledger: Ledger.instance)
        @ledger = ledger
      end

      # Whether this request should be answered locally.
      #
      # @param method [Symbol] HTTP method
      # @param path [String, nil] Request path
      # @return [Boolean]
      def simulates?(method, path)
        return false unless DhanHQ.configuration&.dry_run?

        WritePaths.mutating?(method, path) || replayable_read?(method, path)
      end

      # Builds — and logs — the response for a simulated request.
      #
      # @param method [Symbol] HTTP method
      # @param path [String] Request path
      # @param payload [Hash] The request body that will not be sent
      # @return [ActiveSupport::HashWithIndifferentAccess]
      def response_for(method, path, payload)
        return replay(path) if replayable_read?(method, path)

        log(method, path, payload)
        body = simulated_body(method, path, payload)
        body.merge("dryRun" => true, "method" => method.to_s.upcase, "path" => path)
            .with_indifferent_access
      end

      private

      # A GET for an id this simulator minted. Only reachable in dry run, so
      # intercepting it never shadows a real read.
      def replayable_read?(method, path)
        method == :get && path.to_s.include?(ID_PREFIX)
      end

      def replay(path)
        order_id = path.to_s[ID_PATTERN]
        record = @ledger.fetch(order_id)
        return record.with_indifferent_access if record

        # Simulated in another process, or evicted from the ledger. Answer with the
        # minimum a caller needs rather than falling through to a live request.
        { "orderId" => order_id, "orderStatus" => DhanHQ::Constants::OrderStatus::TRANSIT, "dryRun" => true }
          .with_indifferent_access
      end

      def simulated_body(method, path, payload)
        if WritePaths.multi_order?(path)
          simulated_basket(payload)
        elsif WritePaths.order_placement?(method, path)
          simulated_order(payload)
        else
          {}
        end
      end

      # Echoes the submitted fields back alongside the fabricated id, so a model built
      # from the ledger record looks like the order that would have been placed.
      def simulated_order(payload)
        order_id = generate_id
        record = stringify(payload).merge(
          "orderId" => order_id,
          "orderStatus" => DhanHQ::Constants::OrderStatus::TRANSIT,
          "dryRun" => true
        )
        @ledger.record(order_id, record)
        { "orderId" => order_id, "orderStatus" => DhanHQ::Constants::OrderStatus::TRANSIT }
      end

      # One result per submitted leg, keyed by the caller's sequence, mirroring the
      # real basket response.
      def simulated_basket(payload)
        legs = stringify(payload)["orders"]
        legs = [] unless legs.is_a?(Array)

        orders = legs.each_with_index.map do |leg, index|
          order_id = generate_id
          sequence = (leg.is_a?(Hash) ? leg["sequence"] : nil) || (index + 1).to_s
          @ledger.record(order_id, (leg.is_a?(Hash) ? leg : {}).merge("orderId" => order_id, "dryRun" => true))
          {
            "orderId" => order_id,
            "sequence" => sequence,
            "orderStatus" => DhanHQ::Constants::OrderStatus::TRANSIT
          }
        end

        { "orders" => orders }
      end

      def generate_id
        "#{ID_PREFIX}#{SecureRandom.hex(6).upcase}"
      end

      def stringify(payload)
        payload.is_a?(Hash) ? payload.transform_keys(&:to_s) : {}
      end

      def log(method, path, payload)
        DhanHQ.logger&.warn(
          JSON.generate(
            event: "DHAN_DRY_RUN",
            method: method.to_s.upcase,
            path: path,
            payload: payload.is_a?(Hash) ? payload : nil
          )
        )
      end
    end
  end
end
