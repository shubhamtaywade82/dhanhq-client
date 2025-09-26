# frozen_string_literal: true

module DhanHQ
  module Models
    class KillSwitch < BaseModel
      HTTP_PATH = "/v2/killswitch"

      class << self
        def resource
          @resource ||= DhanHQ::Resources::KillSwitch.new
        end

        def update(status)
          resource.update(kill_switch_status: status)
        end

        def activate
          update("ACTIVATE")
        end

        def deactivate
          update("DEACTIVATE")
        end
      end

      def validation_contract
        nil
      end
    end
  end
end
