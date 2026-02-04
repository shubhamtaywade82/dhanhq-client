# frozen_string_literal: true

module DhanHQ
  # Base wrapper exposing RESTful helpers used by resource classes.
  class BaseResource < BaseAPI
    def initialize(api_type: self.class::API_TYPE)
      super(api_type: api_type) # rubocop:disable Style/SuperArguments
    end

    # Fetches all records for the resource.
    #
    # @return [Array<Hash>, Hash]
    def all
      get("")
    end

    # Retrieves a single resource by identifier.
    #
    # @param id [String, Integer]
    # @return [Hash]
    def find(id)
      get("/#{id}")
    end

    # Creates a new resource instance.
    #
    # @param params [Hash]
    # @return [Hash]
    def create(params)
      post("", params: params)
    end

    # Updates an existing resource.
    #
    # @param id [String, Integer]
    # @param params [Hash]
    # @return [Hash]
    def update(id, params)
      put("/#{id}", params: params)
    end

    # Deletes a resource by identifier.
    #
    # @param id [String, Integer]
    # @return [Hash]
    def delete(id)
      super("/#{id}")
    end
  end
end
