# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # Ruby wrapper around the `/v2/profile` endpoint. Provides typed accessors
    # and snake_case keys while leaving the underlying response untouched.
    class Profile < BaseModel
      HTTP_PATH = "/v2/profile"

      attributes :dhan_client_id, :token_validity, :active_segment, :ddpi,
                 :mtf, :data_plan, :data_validity

      class << self
        ##
        # Provides a shared instance of the profile resource.
        #
        # @return [DhanHQ::Resources::Profile]
        def resource
          @resource ||= DhanHQ::Resources::Profile.new
        end

        ##
        # Fetch the authenticated user's profile details.
        #
        # @return [DhanHQ::Models::Profile, nil]
        def fetch
          response = resource.fetch
          return nil unless response.is_a?(Hash)

          new(response, skip_validation: true)
        end
      end

      def validation_contract
        nil
      end
    end
  end
end

