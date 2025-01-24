# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"
require "active_support/inflector"
module DhanHQ
  class BaseResource
    attr_reader :attributes, :errors

    def initialize(attributes = {})
      @attributes = attributes
      @errors = {}
      validate!
      assign_attributes
    end

    def valid?
      @errors.empty?
    end

    def to_request_params
      camelize_keys(@attributes)
    end

    def self.build_from_response(response)
      return new(response[:data]) if response[:status] == "success"

      ErrorObject.new(response)
    end

    private

    def validate!
      contract = validation_contract
      return unless contract

      result = contract.call(@attributes)
      @errors = result.errors.to_h unless result.success?
    end

    def assign_attributes
      @attributes.each do |key, value|
        define_singleton_method(snake_case(key)) { value }
        define_singleton_method(key) { value }
      end
    end

    def snake_case(key)
      key.to_s.underscore.to_sym
    end

    def camelize_keys(hash)
      hash.transform_keys { |key| key.to_s.camelize(:lower) }
    end

    def validation_contract
      raise NotImplementedError, "#{self.class.name} must implement `validation_contract`."
    end

    def api_client
      @api_client ||= DhanHQ::Client.new
    end
  end

  # A helper class for error responses
  class ErrorObject
    attr_reader :message, :errors

    def initialize(response)
      @message = response[:message] || "An error occurred"
      @errors = response[:errors] || {}
    end

    def success?
      false
    end
  end
end
