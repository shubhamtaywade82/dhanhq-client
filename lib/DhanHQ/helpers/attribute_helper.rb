# frozen_string_literal: true

module DhanHQ
  module AttributeHelper
    # Convert keys from snake_case to camelCase
    #
    # @param hash [Hash] The hash to convert
    # @return [Hash] The camelCased hash
    def camelize_keys(hash)
      hash.transform_keys { |key| key.to_s.camelize(:lower) }
    end

    # Convert keys from snake_case to TitleCase
    #
    # @param hash [Hash] The hash to convert
    # @return [Hash] The TitleCased hash
    def titleize_keys(hash)
      hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    end

    # Convert keys from camelCase to snake_case
    #
    # @param key [String] The key to convert
    # @return [Symbol] The snake_cased key
    def snake_case(key)
      key.to_s.underscore.to_sym
    end

    # Normalize attribute keys to be accessible as both snake_case and camelCase
    #
    # @param hash [Hash] The attributes hash
    # @return [HashWithIndifferentAccess] The normalized attributes
    def normalize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        string_key = key.to_s
        result[string_key] = value
        result[string_key.underscore] = value
      end.with_indifferent_access
    end

    # Override `inspect` to display instance variables instead of attributes hash
    #
    # @return [String] Readable debug output for the object
    def inspect
      instance_vars = self.class.defined_attributes.map { |attr| "#{attr}: #{instance_variable_get(:"@#{attr}")}" }
      "#<#{self.class.name} #{instance_vars.join(", ")}>"
    end

    # def format_params(path, params)
    #   return params unless params.is_a?(Hash)

    #   if optionchain_api?(path)
    #     titleize_keys(params)
    #   else
    #     camelize_keys(params)
    #   end
    # end

    # def camelize_keys(hash)
    #   hash.transform_keys { |key| key.to_s.camelize(:lower) }
    # end

    # def titleize_keys(hash)
    #   hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    # end

    # def optionchain_api?(path)
    #   path.include?("/optionchain")
    # end
  end
end
