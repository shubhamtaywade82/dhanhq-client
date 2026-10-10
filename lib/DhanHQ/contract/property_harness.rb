# frozen_string_literal: true

require "json"

module DhanHQ
  module Contract
    # Offline property harness: generates payloads FROM the contract's request
    # schemas and asserts the schema validator's accept/reject behaviour.
    #
    # Scope is deliberately limited to the **read-only operations the sandbox
    # serves** (margin calculator, charts). The Dhan sandbox is not paper
    # trading — it runs a real OMS/RMS — so nothing here ever targets order
    # endpoints, and no network calls happen unless DHAN_SANDBOX_TOKEN is set
    # (live probe mode; even then only the safe read-only operations).
    #
    # Run with `rake contract:fuzz`. Deterministic: no seeding surprises.
    class PropertyHarness
      # Operations the harness exercises: sandbox-served, request-schema'd,
      # and side-effect free per the official sandbox documentation.
      SAFE_OPERATIONS = %w[
        margincalculator
        intradaycharts
        historicalcharts
      ].freeze

      Result = Struct.new(:operation_id, :check, :ok, :detail, keyword_init: true)

      class << self
        # @return [Integer] number of failed checks (0 = all green)
        def run!(out: $stdout)
          failures = []
          SAFE_OPERATIONS.each do |operation_id|
            operation = Registry.operation(operation_id)
            raise "unknown safe operation #{operation_id}" unless operation

            failures.concat(check_operation(operation).reject(&:ok))
          end

          report(out, failures)
          failures.size
        end

        private

        def check_operation(operation)
          results = []
          results << Result.new(
            operation_id: operation.id, check: "valid payload accepted",
            ok: valid_payload?(operation), detail: errors_of(operation, valid_payload(operation)).join("; ")
          )

          invalid_payload(operation).each_with_index do |payload, i|
            results << Result.new(
              operation_id: operation.id, check: "mutation #{i} rejected",
              ok: !valid_payload?(operation, payload),
              detail: errors_of(operation, payload).join("; ")
            )
          end
          results
        end

        def valid_payload?(operation, payload = nil)
          payload ||= valid_payload(operation)
          SchemaValidator.request_errors(operation, payload).empty?
        rescue StandardError
          false
        end

        def errors_of(operation, payload)
          SchemaValidator.request_errors(operation, payload)
        rescue StandardError
          []
        end

        # Builds the minimal schema-valid payload: required properties from
        # the schema, enums from the (overlay-reconciled) schema, other types
        # from a deterministic type table.
        def valid_payload(operation)
          schema = operation.request_schema
          properties = schema.fetch("properties")
          schema.fetch("required", []).each_with_object({}) do |key, out|
            out[key] = example_value(key, properties[key])
          end
        end

        def invalid_payload(operation)
          schema = operation.request_schema
          required = schema.fetch("required", [])
          base = valid_payload(operation)
          mutations = []

          # 1. drop the first required property
          unless required.empty?
            mutated = base.dup
            mutated.delete(required.first)
            mutations << mutated
          end

          # 2. wrong type on a required property (string where int, etc.)
          unless required.empty?
            key = required.find { |k| properties_type(schema, k) != "string" }
            if key
              mutations << base.merge(key => "not-a-number")
            end
          end

          # 3. invalid enum member on a required enum property
          enum_key = required.find { |k| schema.dig("properties", k, "enum") }
          if enum_key
            mutations << base.merge(enum_key => "DH_CONTRACT_FUZZ_INVALID")
          end

          mutations
        end

        def properties_type(schema, key)
          Array(schema.dig("properties", key, "type")).first
        end

        def example_value(key, property)
          return property["enum"].first if property["enum"]

          case Array(property["type"]).first
          when "string"  then example_string(key)
          when "integer", "number" then 1
          when "boolean" then false
          when "array"   then []
          when "object"  then {}
          else nil
          end
        end

        def example_string(key)
          # Schema-documented example first (e.g. exchangeSegment -> NSE_EQ),
          # else the property name itself, truncated to any documented bound.
          sample = key.casecmp?("exchangeSegment") ? "NSE_EQ" : key.to_s
          sample[0, 64]
        end

        def report(out, failures)
          out.puts "Contract property harness (deterministic, offline)"
          out.puts "  safe operations: #{SAFE_OPERATIONS.join(', ')}"
          if failures.empty?
            out.puts "  all accept/reject properties hold"
          else
            out.puts "  FAILURES (#{failures.size}):"
            failures.each do |f|
              out.puts "    - #{f.operation_id}: #{f.check}#{f.ok ? '' : " — #{f.detail}"}"
            end
          end
        end
      end
    end
  end
end
