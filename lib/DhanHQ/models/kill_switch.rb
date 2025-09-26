# frozen_string_literal: true

module DhanHQ
  module Models
    # Model helper to toggle the trading kill switch.
    class KillSwitch < BaseModel
      # Base path used by the kill switch resource.
      HTTP_PATH = "/v2/killswitch"

      class << self
        # Shared resource for kill switch operations.
        #
        # @return [DhanHQ::Resources::KillSwitch]
        def resource
          @resource ||= DhanHQ::Resources::KillSwitch.new
        end

        # Updates the kill switch status.
        #
        # @param status [String]
        # @return [Hash]
        def update(status)
          resource.update(kill_switch_status: status)
        end

        # Activates the kill switch for the account.
        #
        # @return [Hash]
        def activate
          update("ACTIVATE")
        end

        # Deactivates the kill switch for the account.
        #
        # @return [Hash]
        def deactivate
          update("DEACTIVATE")
        end
      end

      # No explicit validation contract is required for kill switch updates.
      #
      # @return [nil]
      def validation_contract
        nil
      end
    end
  end
end

