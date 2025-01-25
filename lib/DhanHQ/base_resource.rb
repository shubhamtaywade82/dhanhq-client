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

    # Class Methods

    class << self
      # Find a resource by ID
      #
      # @param id [String] The ID of the resource
      # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject] The resource or error object
      def find(id)
        response = api_client.get("#{resource_path}/#{id}")
        build_from_response(response)
      end

      # Find all resources
      #
      # @return [Array<DhanHQ::BaseResource>, DhanHQ::ErrorObject] An array of resources or error object
      def all
        response = api_client.get(resource_path)
        return ErrorObject.new(response) unless response[:status] == "success"

        response[:data].map { |attributes| new(attributes) }
      end

      # Create a new resource
      #
      # @param attributes [Hash] The attributes of the resource
      # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject] The resource or error object
      def create(attributes)
        response = api_client.post(resource_path, attributes)
        build_from_response(response)
      end

      # Build a resource object from an API response
      #
      # @param response [Hash] API response
      # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject]
      def build_from_response(response)
        return new(response[:data]) if response[:status] == "success"

        DhanHQ::ErrorObject.new(response)
      end

      # Retrieve the resource path for the API
      #
      # @return [String] The resource path
      def self.resource_path
        self::HTTP_PATH
      end
    end

    # Update an existing resource
    #
    # @param attributes [Hash] Attributes to update
    # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject]
    def update(attributes = {})
      response = self.class.api_client.put("#{self.class.resource_path}/#{id}", params: attributes)
      self.class.build_from_response(response)
    end

    # Delete the resource
    #
    # @return [Boolean] True if deletion was successful
    def delete
      response = self.class.api_client.delete("#{self.class.resource_path}/#{id}")
      response[:status] == "success"
    rescue StandardError
      false
    end

    private

    # Placeholder for the resource path
    #
    # @raise [NotImplementedError] If not implemented in a subclass
    def resource_path
      raise NotImplementedError, "#{name} must implement `resource_path`."
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
