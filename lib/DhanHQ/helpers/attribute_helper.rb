# frozen_string_literal: true

module DhanHQ
  module AttributeHelper
    # Convert keys from snake_case to camelCase
    #
    # @param hash [Hash] The hash to convert
    # @return [Hash] The camelCased hash
    def self.camelize_keys(hash)
      hash.transform_keys { |key| key.to_s.camelize(:lower) }
    end

    def self.titleize_keys(hash)
      hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    end

    # Convert keys from camelCase to snake_case
    #
    # @param key [String] The key to convert
    # @return [Symbol] The snake_cased key
    def self.snake_case(key)
      key.to_s.underscore.to_sym
    end

    # Converts keys from snake_case to camelCase
    def camelize_keys(hash)
      hash.transform_keys { |key| key.to_s.camelize(:lower) }
    end

    # Converts keys from snake_case to TitleCase
    def titleize_keys(hash)
      hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    end

    # Normalize attribute keys to be accessible as both snake_case and camelCase
    #
    # @param hash [Hash] The attributes hash
    # @return [HashWithIndifferentAccess] The normalized attributes
    def self.normalize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        string_key = key.to_s
        result[string_key] = value
        result[string_key.underscore] = value
      end.with_indifferent_access
    end

    # Normalize attribute keys to be accessible as both snake_case and camelCase
    #
    # @param hash [Hash] The attributes hash
    # @return [HashWithIndifferentAccess] The normalized attributes
    def normalize_keys(hash)
      normalized_hash = hash.each_with_object({}) do |(key, value), result|
        string_key = key.to_s
        result[string_key] = value
        result[string_key.underscore] = value
      end
      normalized_hash.with_indifferent_access
    end
  end
end
