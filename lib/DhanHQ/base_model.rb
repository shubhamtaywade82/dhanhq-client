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
  class BaseModel
    # Extend & Include Modules
    extend DhanHQ::APIHelper
    extend DhanHQ::AttributeHelper
    extend DhanHQ::ValidationHelper
    extend DhanHQ::RequestHelper

    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper
    include DhanHQ::ValidationHelper
    include DhanHQ::RequestHelper

    # Attribute Accessors
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
    end

    # # Validations (Override in subclasses)
    # def self.validation_contract
    #   raise DhanHQ::Error, "#{name} must define `validation_contract`."
    # end

    # Class methods for resources
    class << self
      # Find a resource by ID
      #
      # @param id [String] The ID of the resource
      # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject] The resource or error object
      def find(id)
        response = api_client.get("#{resource_path}/#{id}")

        build_from_response(response)
      end

      # Find all resources
      #
      # @return [Array<DhanHQ::BaseModel>, DhanHQ::ErrorObject] An array of resources or error object
      def all
        response = api_client.get(resource_path)
        return ErrorObject.new(response) unless success_response?(response)

        response[:data].map { |attributes| new(attributes) }
      end

      def where(params)
        response = api_client.get(resource_path, params)
        success_response?(response) ? response[:data].map { |attr| new(attr) } : []
      end

      # Create a new resource
      #
      # @param attributes [Hash] The attributes of the resource
      # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject] The resource or error object
      def create(attributes)
        # validate_params!(attributes, validation_contract)

        response = api_client.post(resource_path, attributes)
        build_from_response(response)
      end

      # Retrieve the resource path for the API
      #
      # @return [String] The resource path
      def resource_path
        self::HTTP_PATH
      end
    end

    # Instance Methods

    # Update an existing resource
    #
    # @param attributes [Hash] Attributes to update
    # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject]
    def update(attributes = {})
      response = self.class.api_client.put("#{self.class.resource_path}/#{id}", params: attributes)

      success_response?(response) ? self.class.build_from_response(response) : DhanHQ::ErrorObject.new(response)
    end

    def save
      new_record? ? self.class.create(attributes) : update(attributes)
    end

    def save!
      raise DhanHQ::ErrorObject, "Failed to save the record" unless save
    end

    # Delete the resource
    #
    # @return [Boolean] True if deletion was successful
    def delete
      response = self.class.api_client.delete("#{self.class.resource_path}/#{id}")
      success_response?(response)
    rescue StandardError
      false
    end

    def destroy
      response = self.class.api_client.delete("#{self.class.resource_path}/#{id}")
      success_response?(response)
    rescue StandardError
      false
    end

    def persisted?
      !!id
    end

    def new_record?
      !persisted?
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

    # Dynamically assign attributes as methods
    def assign_attributes
      self.class.defined_attributes&.each do |attr|
        instance_variable_set(:"@#{attr}", @attributes[attr])
        define_singleton_method(attr) { instance_variable_get(:"@#{attr}") }
        define_singleton_method(attr.to_s.camelize(:lower)) { instance_variable_get(:"@#{attr}") }
      end
    end

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
