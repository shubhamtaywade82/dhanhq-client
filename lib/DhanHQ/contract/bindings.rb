# frozen_string_literal: true

require "yaml"

module DhanHQ
  module Contract
    # Loads and validates lib/DhanHQ/contract/bindings.yml — the explicit map
    # between the gem's resource methods and the contract's operationIds.
    #
    # This file IS the conformance link: the executable conformance spec
    # cross-checks it against both the resource classes and the vendored
    # OpenAPI documents, so drift in any of the three is a failing test.
    class Bindings
      PATH = File.expand_path("bindings.yml", __dir__)

      class << self
        # @return [Hash{String => Hash{String => String}}] resource class name →
        #   method name → operationId
        def table
          @table ||= parsed.fetch("bindings")
        end

        # @return [Hash{String => Hash}] operationId → {reason:}
        def unbound_operations
          @unbound_operations ||= parsed.fetch("unbound_operations")
        end

        # @return [Array<Hash>] entries with verb, path and reason keys — gem
        #   endpoints that must NOT resolve to any contract operation
        def unmapped_gem_endpoints
          @unmapped_gem_endpoints ||= parsed.fetch("unmapped_gem_endpoints")
        end

        # @param resource_name [String] e.g. "Resources::Orders"
        # @param method [Symbol, String] e.g. :create
        # @return [String, nil] operationId
        def operation_id_for(resource_name, method)
          table.dig(resource_name, method.to_s)
        end

        # @return [Array<String>] every bound operationId (with duplicates)
        def all_operation_ids
          table.values.flat_map(&:values)
        end

        def reset!
          @parsed = nil
          @table = nil
          @unbound_operations = nil
          @unmapped_gem_endpoints = nil
        end

        private

        def parsed
          @parsed ||= YAML.safe_load(File.read(PATH), aliases: true)
        rescue Psych::SyntaxError => e
          raise "bindings.yml is not valid YAML: #{e.message}"
        end
      end
    end
  end
end
