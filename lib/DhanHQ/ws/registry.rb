# frozen_string_literal: true

require "concurrent"

module DhanHQ
  module WS
    module Registry
      @clients = Concurrent::Array.new

      class << self
        def register(client)
          @clients << client
        end

        def unregister(client)
          @clients.delete(client)
        end

        def stop_all
          @clients.each do |c|
            c.stop
          rescue StandardError
            nil
          end
          @clients.clear
        end

        def list
          @clients.dup
        end
      end
    end
  end
end
