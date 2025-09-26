# frozen_string_literal: true

require "concurrent"

module DhanHQ
  module WS
    # Maintains the current subscription state and performs diffing so that the
    # client only sends incremental subscribe/unsubscribe requests.
    class SubState
      def initialize
        @set   = Concurrent::Set.new
        @mutex = Mutex.new
      end

      # Filters out instruments that are already subscribed.
      #
      # @param list [Array<Hash>]
      # @return [Array<Hash>] Instruments that still need to be subscribed.
      def want_sub(list)
        @mutex.synchronize { list.reject { |i| @set.include?(key_for(i)) } }
      end

      # Marks the provided instruments as subscribed.
      #
      # @param list [Array<Hash>]
      # @return [void]
      def mark_subscribed!(list)
        @mutex.synchronize { list.each { |i| @set.add(key_for(i)) } }
      end

      # Filters the instruments that are currently subscribed.
      #
      # @param list [Array<Hash>]
      # @return [Array<Hash>] Instruments that can be unsubscribed.
      def want_unsub(list)
        @mutex.synchronize { list.select { |i| @set.include?(key_for(i)) } }
      end

      # Marks the provided instruments as unsubscribed.
      #
      # @param list [Array<Hash>]
      # @return [void]
      def mark_unsubscribed!(list)
        @mutex.synchronize { list.each { |i| @set.delete(key_for(i)) } }
      end

      # Returns the current subscription snapshot.
      #
      # @return [Array<String>] Instrument identifiers in "SEGMENT:SECID" form.
      def snapshot
        @mutex.synchronize { @set.to_a }
      end

      private

      def key_for(i) = "#{i[:ExchangeSegment]}:#{i[:SecurityId]}"
    end
  end
end
