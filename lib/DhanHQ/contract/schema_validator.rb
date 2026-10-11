# frozen_string_literal: true

require "json_schemer"

module DhanHQ
  module Contract
    # Schema-derived request/response validation.
    #
    # Structural rules (required fields, types, string bounds, enums) come from
    # the vendored OpenAPI documents — never hand-transcribed — and are applied
    # to the final wire payload (after the resource layer's key formatting).
    # Semantic rules the schemas cannot express (lot-size/tick-size multiples,
    # instrument metadata cross-checks) stay in the dry-validation contracts.
    #
    # Enabled per configuration:
    # * +config.validate_requests+ (default +true+) — raises
    #   {DhanHQ::ValidationError} before the request leaves the process.
    # * +config.validate_responses+ (default +false+) — collects response
    #   errors; used by contract specs and available for paranoid deployments.
    class SchemaValidator
      class << self
        # Validates a request payload against the operation's request schema.
        #
        # @param operation [DhanHQ::Contract::Operation]
        # @param payload [Object] The wire payload (typically a Hash)
        # @return [true, nil] true on success; nil when there is nothing to validate
        # @raise [DhanHQ::ValidationError] on schema violations
        def validate_request!(operation, payload)
          return if operation.nil? || operation.request_schema_name.nil?

          # A missing body is validated as an empty one: otherwise client.post(path, nil)
          # would skip validation for every operation with a required request body.
          payload = {} if payload.nil?
          return true if request_schemer(operation).valid?(stringify_keys(payload))

          errors = request_errors(operation, payload)
          raise DhanHQ::ValidationError,
                "#{operation.label} request failed contract validation: " \
                "#{errors.join("; ")}"
        end

        # Collects request violations without raising.
        #
        # @param operation [DhanHQ::Contract::Operation]
        # @param payload [Object]
        # @return [Array<String>]
        def request_errors(operation, payload)
          return [] if operation.nil? || operation.request_schema_name.nil?

          errors_for(request_schemer(operation), payload)
        end

        # Validates a parsed response against the operation's 2xx schema.
        # Non-raising by design: response drift should be observable, not
        # fatal, by default (see config.validate_responses).
        #
        # @param operation [DhanHQ::Contract::Operation]
        # @param parsed [Object] Parsed JSON response
        # @return [Array<String>] Empty when the response matches the contract
        def response_errors(operation, parsed)
          schema_name = operation&.response_schema_names&.first
          return [] unless schema_name
          return [] unless parsed.is_a?(Hash) || parsed.is_a?(Array)

          errors_for(schemer_ref(schema_name), parsed)
        end

        private

        # One schemer over the whole live document: internal $refs
        # (#/components/schemas/...) resolve natively, including nested ones
        # (MultiOrderItemRequest inside MultiOrderRequest, ScriptItem inside
        # MultiScripMarginCalcRequest, ...).
        def document_schemer
          @document_schemer ||= JSONSchemer.schema(Registry.live_doc)
        end

        def request_schemer(operation)
          schemer_ref(operation.request_schema_name)
        end

        def schemer_ref(schema_name)
          document_schemer.ref("#/components/schemas/#{schema_name}")
        end

        # @param schemer [JSONSchemer::Schema] A document or ref schemer
        # @param data [Object]
        # @return [Array<String>] Human-readable pointer + type per violation
        def errors_for(schemer, data)
          schemer.validate(stringify_keys(data)).map do |err|
            pointer = err["schema_pointer"]
            detail_items = err["details"]&.filter_map { |k, v| "#{k}: #{v.is_a?(Array) ? v.join(", ") : v}" if v }
            details = detail_items&.join(", ")
            [pointer, err["type"], details].compact.join(" ").strip
          end
        end

        # JSON Schema wants string keys; the gem tolerates symbols everywhere.
        def stringify_keys(value)
          case value
          when Hash
            value.each_with_object({}) do |(k, v), out|
              out[k.to_s] = stringify_keys(v)
            end
          when Array
            value.map { |v| stringify_keys(v) }
          else
            value
          end
        end
      end
    end
  end
end
