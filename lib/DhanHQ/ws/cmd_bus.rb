# frozen_string_literal: true

module DhanHQ
  module WS
    # Thread-safe queue that buffers subscription commands until the
    # connection is ready to send them.
    class CmdBus
      # Represents a subscription command queued for execution.
      Command = Struct.new(:op, :payload, keyword_init: true)

      def initialize
        @q = Queue.new
      end

      # Queues a subscribe command.
      #
      # @param list [Array<Hash>] Instruments to subscribe.
      # @return [Command]
      def sub(list) = @q.push(Command.new(op: :sub, payload: list))

      # Queues an unsubscribe command.
      #
      # @param list [Array<Hash>] Instruments to unsubscribe.
      # @return [Command]
      def unsub(list) = @q.push(Command.new(op: :unsub, payload: list))

      # Drains all queued commands without blocking.
      #
      # @return [Array<Command>]
      def drain
        out = []
        loop { out << @q.pop(true) }
      rescue ThreadError
        out
      end
    end
  end
end
