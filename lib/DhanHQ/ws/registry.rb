# frozen_string_literal: true

require "concurrent"

module DhanHQ
  module WS
    class Registry
      @clients = []
      class << self
        def register(client)
          @clients << client unless @clients.include?(client)
        end

        def unregister(client)
          @clients.delete(client)
        end

        def stop_all
          @clients.dup.each do |c|
            c.stop
          rescue StandardError
          end
          @clients.clear
        end
      end
    end

    # convenience API
    def self.disconnect_all_local!
      Registry.stop_all
    end
  end
end
