# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/inflector"

module DhanHQ
  # Base class for resource objects
  # Handles validation, attribute mapping, and response parsing
  class BaseResource
    attr_reader :attributes, :errors

    # Initialize a new resource object
    #
    # @param attributes [Hash] The attributes of the resource
    def initialize(attributes = {})
      @attributes = attributes
      @errors = {}
      validate!
      assign_attributes
    end

    # Check if the resource is valid
    #
    # @return [Boolean] True if valid, false otherwise
    def valid?
      @errors.empty?
    end

    # Convert attributes to camelCase for API requests
    #
    # @return [Hash] The camelCased attributes
    def to_request_params
      camelize_keys(@attributes)
    end

    # Build a resource object from an API response
    #
    # @param response [Hash] The API response
    # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject] A resource or error object
    def self.build_from_response(response)
      return new(response[:data]) if response[:status] == "success"

      ErrorObject.new(response)
    end

    private

    # Validate the attributes using the validation contract
    def validate!
      contract = validation_contract
      return unless contract

      result = contract.call(@attributes)
      @errors = result.errors.to_h unless result.success?
    end

    # Dynamically assign attributes as methods
    def assign_attributes
      @attributes.each do |key, value|
        define_singleton_method(snake_case(key)) { value }
        define_singleton_method(key) { value }
      end
    end

    # Convert keys from camelCase to snake_case
    #
    # @param key [String] The key to convert
    # @return [Symbol] The snake_cased key
    def snake_case(key)
      key.to_s.underscore.to_sym
    end

    # Convert keys from snake_case to camelCase
    #
    # @param hash [Hash] The hash to convert
    # @return [Hash] The camelCased hash
    def camelize_keys(hash)
      hash.transform_keys { |key| key.to_s.camelize(:lower) }
    end

    # Placeholder for the validation contract
    #
    # @raise [NotImplementedError] If not implemented in a subclass
    def validation_contract
      raise NotImplementedError, "#{self.class.name} must implement `validation_contract`."
    end

    # Provide a reusable API client instance
    #
    # @return [DhanHQ::Client] The client instance
    def api_client
      @api_client ||= DhanHQ::Client.new
    end
  end

  # Helper class for encapsulating API error responses
  class ErrorObject
    attr_reader :message, :errors

    # Initialize an error object
    #
    # @param response [Hash] The API response
    def initialize(response)
      @message = response[:message] || "An error occurred"
      @errors = response[:errors] || {}
    end

    # Check if the response is successful
    #
    # @return [Boolean] False for errors
    def success?
      false
    end
  end
end
