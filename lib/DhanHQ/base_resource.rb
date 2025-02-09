# frozen_string_literal: true

require "dry-validation"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/inflector"

require_relative "helpers/api_helper"
require_relative "helpers/attribute_helper"
require_relative "helpers/validation_helper"
require_relative "helpers/request_helper"

module DhanHQ
  # Base class for resource objects
  # Handles validation, attribute mapping, and response parsing
  class BaseResource
    extend DhanHQ::APIHelper
    extend DhanHQ::AttributeHelper
    extend DhanHQ::ValidationHelper
    extend DhanHQ::RequestHelper

    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper
    include DhanHQ::ValidationHelper
    include DhanHQ::RequestHelper

    attr_reader :attributes, :errors

    # Initialize a new resource object
    #
    # @param attributes [Hash] The attributes of the resource
    def initialize(attributes = {}, skip_validation: false)
      @attributes = normalize_keys(attributes)
      @errors = {}

      validate! unless skip_validation
      assign_attributes
    end

    # Class Methods

    class << self
      attr_reader :defined_attributes

      def attributes(*args)
        @defined_attributes ||= []
        @defined_attributes.concat(args.map(&:to_s))
      end

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

      # # Build a resource object from an API response
      # #
      # # @param response [Hash] API response
      # # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject]
      # def build_from_response(response)
      #   return new(response[:data].with_indifferent_access, skip_validation: true) if response[:status] == "success"

      #   DhanHQ::ErrorObject.new(response)
      # end

      # Retrieve the resource path for the API
      #
      # @return [String] The resource path
      def resource_path
        self::HTTP_PATH
      end

      # # Provide a reusable API client instance
      # #
      # # @return [DhanHQ::Client] The client instance
      # def api_client
      #   @api_client ||= DhanHQ::Client.new
      # end

      # # Validate the attributes using the validation contract
      # #
      # # @param params [Hash] The parameters to validate
      # # @param contract_class [Class] The contract class to use for validation
      # def validate_params!(params, contract_class = validation_contract)
      #   contract = contract_class.new
      #   result = contract.call(params)
      #   raise DhanHQ::Error, "Validation Error: #{result.errors.to_h}" unless result.success?
      # end
    end

    # Update an existing resource
    #
    # @param attributes [Hash] Attributes to update
    # @return [DhanHQ::BaseResource, DhanHQ::ErrorObject]
    def update(attributes = {})
      response = self.class.api_client.put("#{self.class.resource_path}/#{id}", params: attributes)
      return self.class.build_from_response(response) if response[:status] == "success"

      DhanHQ::ErrorObject.new(response)
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

    # Format request parameters before sending to API
    #
    # @return [Hash] The camelCased attributes
    def to_request_params
      optionchain_api? ? titleize_keys(@attributes) : camelize_keys(@attributes)
    end

    def id
      @attributes[:id] || @attributes[:order_id] || @attributes[:security_id]
    end

    # # Validate the attributes using the validation contract
    # def validate!
    #   contract = validation_contract
    #   return unless contract

    #   result = contract.call(@attributes)
    #   @errors = result.errors.to_h unless result.success?

    #   raise DhanHQ::Error, "Validation Error: #{@errors}" unless valid?
    # end

    # # Validate the attributes using the validation contract
    # #
    # # @param params [Hash] The parameters to validate
    # # @param contract_class [Class] The contract class to use for validation
    # def validate_params!(params, contract_class = validation_contract)
    #   contract = contract_class.new
    #   result = contract.call(params)

    #   raise DhanHQ::Error, "Validation Error: #{result.errors.to_h}" unless result.success?
    # end

    # Dynamically assign attributes as methods
    def assign_attributes
      self.class.defined_attributes&.each do |attr|
        instance_variable_set(:"@#{attr}", @attributes[attr])
        define_singleton_method(attr) { instance_variable_get(:"@#{attr}") }
        define_singleton_method(attr.to_s.camelize(:lower)) { instance_variable_get(:"@#{attr}") }
      end
    end

    # # Normalize attribute keys to be accessible as both snake_case and camelCase
    # #
    # # @param hash [Hash] The attributes hash
    # # @return [HashWithIndifferentAccess] The normalized attributes
    # def normalize_keys(hash)
    #   normalized_hash = hash.each_with_object({}) do |(key, value), result|
    #     string_key = key.to_s
    #     result[string_key] = value
    #     result[string_key.underscore] = value
    #   end
    #   normalized_hash.with_indifferent_access
    # end

    # # Convert keys from camelCase to snake_case
    # #
    # # @param key [String] The key to convert
    # # @return [Symbol] The snake_cased key
    # def snake_case(key)
    #   key.to_s.underscore.to_sym
    # end

    # # Convert keys from snake_case to camelCase
    # #
    # # @param hash [Hash] The hash to convert
    # # @return [Hash] The camelCased hash
    # def camelize_keys(hash)
    #   hash.transform_keys { |key| key.to_s.camelize(:lower) }
    # end

    # def titleize_keys(hash)
    #   hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    # end

    # # Placeholder for the validation contract
    # #
    # # @raise [NotImplementedError] If not implemented in a subclass
    # def validation_contract
    #   raise NotImplementedError, "#{self.class.name} must implement `validation_contract`."
    # end

    # # Provide a reusable API client instance
    # #
    # # @return [DhanHQ::Client] The client instance
    # def api_client
    #   @api_client ||= DhanHQ::Client.new
    # end

    # # Override `inspect` to display instance variables instead of attributes hash
    # #
    # # @return [String] Readable debug output for the object
    # def inspect
    #   instance_vars = self.class.defined_attributes.map { |attr| "#{attr}: #{instance_variable_get(:"@#{attr}")}" }
    #   "#<#{self.class.name} #{instance_vars.join(", ")}>"
    # end

    def optionchain_api?
      self.class.name.include?("OptionChain")
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
