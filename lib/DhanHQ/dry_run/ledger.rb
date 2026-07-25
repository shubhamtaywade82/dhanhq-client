# frozen_string_literal: true

require "concurrent"

module DhanHQ
  module DryRun
    # Remembers the orders a dry run pretended to place, so a follow-up read for one
    # of those simulated ids can be answered locally.
    #
    # This exists because the high-level models re-fetch after placing:
    # `Models::Order.place` and `GlobalStocks::Order.place` both call `find(order_id)`
    # to return the complete record. Without a ledger that GET would leave the process
    # carrying a `DRYRUN-…` id to the live API, which is both a real network call and a
    # guaranteed miss — so dry run would only have worked for direct
    # {DhanHQ::Client#request} calls, not the API people actually use.
    #
    # Entries are per-process and capped; a long rehearsal evicts its oldest records
    # rather than growing without bound.
    class Ledger
      # Maximum simulated orders retained before the oldest are evicted.
      MAX_ENTRIES = 500

      def initialize(max_entries: MAX_ENTRIES)
        @max_entries = max_entries
        @records = {}
        @mutex = Mutex.new
      end

      # Process-wide ledger used by {DhanHQ::DryRun::Simulator}.
      #
      # @return [Ledger]
      def self.instance
        @instance ||= new
      end

      # Records a simulated order.
      #
      # @param order_id [String] The simulated order id
      # @param record [Hash] The response to replay for reads of that id
      # @return [Hash] The stored record
      def record(order_id, record)
        @mutex.synchronize do
          @records.delete(order_id)
          @records[order_id] = record
          @records.shift while @records.size > @max_entries
          record
        end
      end

      # Fetches a previously simulated order.
      #
      # @param order_id [String]
      # @return [Hash, nil] nil when the id was never simulated in this process
      def fetch(order_id)
        @mutex.synchronize { @records[order_id] }
      end

      # @return [Integer] Number of retained records
      def size
        @mutex.synchronize { @records.size }
      end

      # Drops every retained record. Intended for test isolation.
      #
      # @return [void]
      def clear
        @mutex.synchronize { @records.clear }
      end
    end
  end
end
