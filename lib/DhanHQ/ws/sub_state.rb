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

      # The desired subscriptions rendered as instrument hashes, ready to be sent as a
      # subscribe frame.
      #
      # The server keeps no subscription state across connections, so a reconnecting
      # client replays this on every new session.
      #
      # @return [Array<Hash>] Instruments with +:ExchangeSegment+ and +:SecurityId+.
      def resubscribe_payload
        snapshot.map do |key|
          segment, security_id = key.split(":")
          { ExchangeSegment: segment, SecurityId: security_id }
        end
      end

      private

      def key_for(instrument) = "#{instrument[:ExchangeSegment]}:#{instrument[:SecurityId]}"
    end
  end
end
