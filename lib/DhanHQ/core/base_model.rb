# frozen_string_literal: true

require "dry-validation"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/inflector"

module DhanHQ
  # Base class for resource objects
  # Handles validation, attribute mapping, and response parsing
  class BaseModel
    # Extend & Include Modules
    extend DhanHQ::APIHelper
    extend DhanHQ::AttributeHelper
    extend DhanHQ::ValidationHelper
    extend DhanHQ::RequestHelper
    extend DhanHQ::ResponseHelper

    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper
    include DhanHQ::ValidationHelper
    include DhanHQ::RequestHelper
    include DhanHQ::ResponseHelper

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
    # Attributes set by child classes
    class << self
      attr_reader :defined_attributes

      # Registers the set of attributes for this model
      #
      # @param args [Array<Symbol, String>] A list of attribute names
      def attributes(*args)
        @defined_attributes ||= []
        @defined_attributes.concat(args.map(&:to_s))
      end

      # Provide a default API type, can be overridden by child classes
      #
      # e.g., def self.api_type; :data_api; end
      #
      # or override the `api` method entirely
      def api_type
        :order_api
      end

      # Provide a shared BaseAPI instance for this model
      #
      # For child classes, override `api_type` or `api` if needed
      def api
        @api ||= BaseAPI.new(api_type: api_type)
      end

      ##
      # Returns the API resource used by collection methods.
      #
      # Subclasses may override this to return a specialized API class.
      # By default it simply returns {#api}.
      def resource
        api
      end

      # Retrieve the resource path for the API
      #
      # @return [String] The resource path
      def resource_path
        self::HTTP_PATH
      end

      # Every model must either override this or set a Dry::Validation contract if they need validation
      #
      # @return [Dry::Validation::Contract] The validation contract
      def validation_contract
        raise NotImplementedError, "#{name} must implement `validation_contract`"
      end

      # Validate attributes before creating a new instance
      def validate_attributes(attributes)
        contract = validation_contract
        result = contract.call(attributes)

        raise ArgumentError, "Validation failed: #{result.errors.to_h}" if result.failure?
      end

      # == CRUD / Collection Methods

      # Find all resources
      #
      # @return [Array<DhanHQ::BaseModel>, DhanHQ::ErrorObject] An array of resources or error object
      def all
        response = resource.get("")

        parse_collection_response(response)
      end

      # Find a resource by ID
      #
      # @param id [String] The ID of the resource
      # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject] The resource or error object
      def find(id)
        response = resource.get("/#{id}")

        payload = response.is_a?(Array) ? response.first : response
        build_from_response(payload)
      end

      # Fetches records filtered by query parameters.
      #
      # @param params [Hash] Query parameters supported by the API.
      # @return [Array<BaseModel>, BaseModel, DhanHQ::ErrorObject]
      def where(params)
        response = resource.get("", params: params)
        build_from_response(response)
      end

      # Create a new resource
      #
      # @param attributes [Hash] The attributes of the resource
      # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject] The resource or error object
      def create(attributes)
        # validate_params!(attributes, validation_contract)

        response = resource.post("", params: attributes)
        build_from_response(response)
      end

      # Helper method to parse a collection response into model instances
      #
      # @param response [Object] The raw response from the API
      # @return [Array<BaseModel>]
      def parse_collection_response(response)
        # Some endpoints return arrays, others might return a `[:data]` structure
        return [] unless response.is_a?(Array) || (response.is_a?(Hash) && response[:data].is_a?(Array))

        collection = response.is_a?(Array) ? response : response[:data]
        collection.map { |record| new(record) }
      end
    end

    # Instance Methods

    # Update an existing resource
    #
    # @param attributes [Hash] Attributes to update
    # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject]
    def update(attributes = {})
      response = self.class.resource.put("/#{id}", params: attributes)

      success_response?(response) ? self.class.build_from_response(response) : DhanHQ::ErrorObject.new(response)
    end

    # Persists the current resource by delegating to {#create} or {#update}.
    #
    # @return [DhanHQ::BaseModel, DhanHQ::ErrorObject, false]
    def save
      new_record? ? self.class.create(attributes) : update(attributes)
    end

    # Same as {#save} but raises {DhanHQ::Error} when persistence fails.
    #
    # @return [DhanHQ::BaseModel]
    # @raise [DhanHQ::Error] When the record cannot be saved.
    def save!
      result = save
      return result unless result == false || result.nil? || result.is_a?(DhanHQ::ErrorObject)

      error_details =
        if result.is_a?(DhanHQ::ErrorObject)
          result.errors
        elsif @errors && !@errors.empty?
          @errors
        else
          "Unknown error"
        end

      raise DhanHQ::Error, "Failed to save the record: #{error_details}"
    end

    # Delete the resource
    #
    # @return [Boolean] True if deletion was successful
    # Deletes the resource from the remote API.
    #
    # @return [Boolean] True when the server confirms deletion.
    def delete
      response = self.class.resource.delete("/#{id}")
      success_response?(response)
    rescue StandardError
      false
    end

    # Alias for {#delete} maintained for ActiveModel familiarity.
    #
    # @return [Boolean]
    def destroy
      response = self.class.resource.delete("/#{id}")
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

    # Identifier inferred from the loaded attributes.
    #
    # @return [String, Integer, nil]
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

    # Validate attributes using contract
    def valid?
      contract_class = respond_to?(:validation_contract) ? validation_contract : self.class.validation_contract
      return true unless contract_class

      contract = contract_class.is_a?(Class) ? contract_class.new : contract_class
      result = contract.call(@attributes)

      if result.failure?
        @errors = result.errors.to_h
        return false
      end

      true
    end
  end
end
