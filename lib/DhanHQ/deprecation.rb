# frozen_string_literal: true

module DhanHQ
  # Emits a deprecation notice once per call site per process.
  #
  # A trading process can reject hundreds of orders in a session. A notice that fires
  # on every one of them is noise that gets filtered out, which defeats the purpose —
  # the point is for a maintainer to find the handful of call sites still relying on
  # behaviour that is going to change, then fix them.
  module Deprecation
    @warned = {}
    @mutex = Mutex.new

    class << self
      # Logs +message+ the first time this +key+ is seen in this process.
      #
      # A command, not a query: callers that need to know whether a notice was emitted
      # should consult {.warned_keys}.
      #
      # @param key [String, Symbol] Identifies the call site, e.g. the operation name.
      # @param message [String] What is deprecated and what to do instead.
      # @return [void]
      def warn_once(key, message)
        return unless first_warning_for?(key)

        DhanHQ.logger&.warn("[DhanHQ] DEPRECATION: #{message}")
        nil
      end

      # Keys already warned about, for assertions and diagnostics.
      #
      # @return [Array<String>]
      def warned_keys
        @mutex.synchronize { @warned.keys }
      end

      # Forgets every emitted notice, so the next occurrence warns again.
      # Intended for test isolation.
      #
      # @return [void]
      def reset!
        @mutex.synchronize { @warned.clear }
      end

      private

      # Whether this is the first time +key+ has been seen, recording it either way.
      #
      # The check and the record happen under one lock so two threads hitting the same
      # call site at once cannot both decide they are first.
      #
      # @return [Boolean]
      def first_warning_for?(key)
        @mutex.synchronize do
          next false if @warned.key?(key.to_s)

          @warned[key.to_s] = true
        end
      end
    end
  end
end
