# frozen_string_literal: true

module DhanHQ
  module WS
    class CmdBus
      Command = Struct.new(:op, :payload, keyword_init: true)

      def initialize
        @q = Queue.new
      end

      def sub(list)   = @q.push(Command.new(op: :sub,   payload: list))
      def unsub(list) = @q.push(Command.new(op: :unsub, payload: list))

      def drain
        out = []
        out << @q.pop(true) while true
      rescue ThreadError
        out
      end
    end
  end
end
