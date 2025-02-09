# frozen_string_literal: true

module DhanHQ
  module RequestHelper
    # Builds a model object from API response
    #
    # @param response [Hash] API response
    # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject]
    def build_from_response(response)
      return new(response[:data].with_indifferent_access, skip_validation: true) if success_response?(response)

      DhanHQ::ErrorObject.new(response)
    end
  end
end
