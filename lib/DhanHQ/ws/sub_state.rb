# frozen_string_literal: true

require "concurrent"

module DhanHQ
  module WS
    class SubState
      def initialize
        @set   = Concurrent::Set.new
        @mutex = Mutex.new
      end

      def want_sub(list)
        @mutex.synchronize { list.reject { |i| @set.include?(key_for(i)) } }
      end

      def mark_subscribed!(list)
        @mutex.synchronize { list.each { |i| @set.add(key_for(i)) } }
      end

      def want_unsub(list)
        @mutex.synchronize { list.select { |i| @set.include?(key_for(i)) } }
      end

      def mark_unsubscribed!(list)
        @mutex.synchronize { list.each { |i| @set.delete(key_for(i)) } }
      end

      def snapshot
        @mutex.synchronize { @set.to_a }
      end

      private

      def key_for(i) = "#{i[:ExchangeSegment]}:#{i[:SecurityId]}"
    end
  end
end
