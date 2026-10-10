# frozen_string_literal: true

require "concurrent"
require "set"

require_relative "spec_loader"
require_relative "operation"

module DhanHQ
  module Contract
    # The operation registry: the executable index over the vendored DhanHQ
    # contracts. This is the single source of truth for
    #
    # * which operations exist (live + sandbox),
    # * which tier / rate-limit class each belongs to,
    # * whether the sandbox host serves it,
    # * how request keys must be cased, and
    # * resolving a concrete resource call (verb + path) back to its operation.
    #
    # Everything here is derived from contracts/dhanhq/*.openapi.json plus the
    # overlays in contracts/overlays/ — nothing is hand-transcribed from docs.
    class Registry
      class << self
        # All live operations keyed by operationId (overlays included).
        #
        # @return [Hash{String => Operation}]
        def operations
          @operations ||= build_operations
        end

        # @param id [String] operationId
        # @return [Operation, nil]
        def operation(id)
          operations[id]
        end

        # @return [Hash{String => Hash}] Live document's component schemas
        def live_schemas
          @live_schemas ||= live_doc.fetch("components", {}).fetch("schemas", {})
        end

        # @return [Hash] The effective (overlay-applied) live contract
        def live_doc
          @live_doc ||= SpecLoader.load(:live)
        end

        # @return [Hash] The effective (overlay-applied) sandbox contract
        def sandbox_doc
          @sandbox_doc ||= SpecLoader.load(:sandbox)
        end

        # Gem-side endpoint families that are absent from both OpenAPI documents
        # (REVIEW.md M1) yet would otherwise be *misresolved* onto the
        # /orders/{order-id} template, because the wildcard happily captures
        # "iceberg"/"twap" as an order id. resolve() refuses these and returns
        # nil, so the sandbox guard and the conformance suite see the truth.
        RESERVED_UNRESOLVED_PATHS = ["/orders/iceberg", "/orders/twap"].freeze

        # Resolves a resource-layer call to its contract operation.
        #
        # Accepts paths exactly as the resource layer builds them ("/v2/orders",
        # "/v2/orders/123", "/v2/marketfeed/ltp"), normalises the "/v2" prefix
        # the OpenAPI documents do not carry, and matches against path templates
        # (preferring literal segments over wildcards).
        #
        # @param verb [Symbol, String] HTTP verb
        # @param path [String] Request path (may include a query string)
        # @return [Operation, nil] nil when no operation exists — e.g. iceberg
        #   and TWAP order endpoints, which the vendor spec does not define
        def resolve(verb, path)
          verb = verb.to_s.downcase.to_sym
          normalized = normalize_path(path)
          return nil if RESERVED_UNRESOLVED_PATHS.include?(normalized)

          cache = resolve_cache
          cache[[verb, normalized]] ||= begin
            candidates = by_verb[verb] || []
            matches = candidates.select { |op| op.path_regexp.match?(normalized) }
            matches.min_by { |op| [op.wildcard_count, op.path.count("/")] }
          end
        end

        # True when the sandbox host (sandbox.dhan.co/v2) serves this
        # verb+path. Anything absent from the sandbox contract — including
        # docs-only endpoints and endpoints the vendor spec does not define at
        # all (iceberg, TWAP) — is unsupported there.
        #
        # @param verb [Symbol, String]
        # @param path [String]
        # @return [Boolean]
        def sandbox_supported?(verb, path)
          op = resolve(verb, path)
          op ? op.sandbox_supported? : false
        end

        # operationIds present in the sandbox contract (27 vendor + 1 verified via overlay).
        #
        # @return [Set<String>]
        def sandbox_operation_ids
          @sandbox_operation_ids ||= begin
            each_sandbox_op.map { |op| op.fetch("operationId") }.to_set
          end
        end

        # @return [Array<String>] Sorted operationIds of the live contract
        def live_operation_ids
          operations.keys.sort
        end

        # Clears memoized state (spec reloads in tests / rake tasks).
        def reset!
          @operations = nil
          @live_doc = nil
          @sandbox_doc = nil
          @live_schemas = nil
          @by_verb = nil
          @sandbox_operation_ids = nil
          @resolve_cache = nil
        end

        private

        def by_verb
          @by_verb ||= begin
            grouped = Hash.new { |h, k| h[k] = [] }
            operations.each_value { |op| grouped[op.verb] << op }
            grouped.each_value { |ops| ops.sort_by!(&:wildcard_count) }
            grouped
          end
        end

        def resolve_cache
          @resolve_cache ||= Concurrent::Map.new
        end

        def build_operations
          sandbox_ids = sandbox_operation_ids
          sandbox_specs = sandbox_operations_by_id
          ops = {}
          each_live_op do |path, verb, o|
            id = o.fetch("operationId")
            next if ops.key?(id)

            ops[id] = Operation.new(
              id: id,
              verb: verb,
              path: path,
              summary: o["summary"],
              docs_only: o["x-dhan-docs-only"] == true,
              rate_limit_class: o["x-dhan-rate-limit-class"],
              request_schema_name: schema_name_for(o.dig("requestBody", "content")),
              response_schema_names: response_schema_names_for(o),
              sandbox_supported: sandbox_ids.include?(id),
              quirks: sandbox_specs.dig(id, "x-dhan-quirks"),
              docs_url: o["x-dhan-docs-url"]
            )
          end
          ops.freeze
        end

        def each_live_op
          live_doc.fetch("paths", {}).each do |path, item|
            item.each do |verb, o|
              next unless %w[get post put delete patch].include?(verb)
              next unless o.is_a?(Hash) && o["operationId"]

              yield path, verb.to_sym, o
            end
          end
        end

        def each_sandbox_op
          return enum_for(:each_sandbox_op) unless block_given?

          sandbox_doc.fetch("paths", {}).each_value do |item|
            item.each_value do |o|
              next unless o.is_a?(Hash) && o["operationId"]

              yield o
            end
          end
        end

        def sandbox_operations_by_id
          @sandbox_operations_by_id ||= begin
            by_id = {}
            sandbox_doc.fetch("paths", {}).each_value do |item|
              item.each_value do |o|
                next unless o.is_a?(Hash) && o["operationId"]

                by_id[o.fetch("operationId")] = o
              end
            end
            by_id
          end
        end

        def schema_name_for(content)
          return nil unless content.is_a?(Hash)

          json = content["application/json"]
          ref = json.is_a?(Hash) && json.dig("schema", "$ref")
          ref&.split("/")&.last
        end

        def response_schema_names_for(operation)
          operation.fetch("responses", {}).filter_map do |status, resp|
            next unless status.to_s.start_with?("2")

            schema_name_for(resp&.dig("content"))
          end.uniq
        end

        # Strips the version prefix, query strings and trailing slashes the
        # registry's path templates do not carry.
        def normalize_path(path)
          p = path.to_s.dup
          p = p.sub(/\?.*\z/, "")            # query string
          p = p.sub(%r{\A/v2(?=/|\z)}, "")   # version prefix
          p.chomp!("/")
          p = "/#{p}" unless p.start_with?("/")
          p
        end
      end
    end
  end
end
