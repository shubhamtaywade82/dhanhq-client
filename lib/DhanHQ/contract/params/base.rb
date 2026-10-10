# frozen_string_literal: true

module DhanHQ
  module Contract
    # Generated request-param structs (see contracts/dhanhq/*.openapi.json and
    # `rake contract:generate`).
    module Params
      class << self
        # Coerces generated param structs — and collections containing them —
        # to plain hashes. Hashes and anything else pass through untouched, so
        # every call site can apply it unconditionally.
        #
        # @param obj [Object]
        # @return [Object] a Hash when a struct was passed, else the input
        def coerce(obj)
          case obj
          when Base then obj.to_h
          when Array then obj.map { |item| coerce(item) }
          else obj
          end
        end
      end

      # Base class for the generated param structs.
      #
      # A struct is an immutable, self-validating request body derived from the
      # vendored OpenAPI schema of one operation. Construction fails fast —
      # unknown keys, missing required fields, enum violations and type
      # violations raise {DhanHQ::ValidationError} at the call site instead of
      # surfacing as a DH-xxx rejection from the API mid-session.
      #
      # Semantic rules the schemas cannot express (lot-size multiples,
      # instrument cross-checks) remain in the dry-validation contracts and the
      # risk pipeline; a struct only encodes the contract's structural truth.
      #
      # @example
      #   order = DhanHQ::Contract::Params::OrderParams.new(
      #     transaction_type: "BUY", exchange_segment: "NSE_EQ",
      #     product_type: "CNC", order_type: "LIMIT",
      #     security_id: "11536", quantity: 5
      #   )
      #   DhanHQ::Resources::Orders.new.create(order)   # coerced transparently
      class Base
        # JSON boolean domain, hoisted out of the type loop (rubocop-perf).
        BOOLEAN_VALUES = [true, false].freeze

        # Fields the client injects onto the wire payload regardless of what
        # the caller passes (RequestHelper#with_injected_client_id). They are
        # removed from the generated required list — a struct must never force
        # the caller to supply what the transport layer owns.
        INJECTED_FIELDS = %w[dhanClientId].freeze

        class << self
          # Builds a struct from a hash whose keys may be snake_case or
          # camelCase, symbols or strings — the same laxity the resources
          # already offer. Idempotent: a Base instance passes through.
          #
          # @param hash [Hash, DhanHQ::Contract::Params::Base, nil]
          # @return [DhanHQ::Contract::Params::Base]
          def from_h(hash)
            return hash if hash.is_a?(Base)
            return new if hash.nil?

            normalized = hash.each_with_object({}) do |(key, value), out|
              out[key.to_s.underscore.to_sym] = value
            end
            new(**normalized)
          end

          # @return [Hash{String => String}] wire (schema) key => struct field name
          def wire_key_map
            @wire_key_map ||= self::FIELDS.each_with_object({}) do |(name, spec), out|
              out[spec.fetch("wire_key")] = name
            end.freeze
          end

          # All four accessors use +self::CONSTANT+ (not the bare constant) on
          # purpose: a bare FIELDS inside Base's singleton methods would
          # resolve through Base's *lexical* scope and NameError, because the
          # constants live on the generated subclasses.
          def schema_name = self::SCHEMA_NAME
          def operation_ids = self::OPERATION_IDS
          def fields = self::FIELDS
          def required_fields = self::REQUIRED
        end

        # Validates and freezes the struct.
        #
        # @raise [DhanHQ::ValidationError] on unknown keys, missing required
        #   fields, enum violations or type violations
        def initialize(**kwargs)
          errors = validate_kwargs(kwargs)
          unless errors.empty?
            raise DhanHQ::ValidationError,
                  "#{self.class.name}: #{errors.join("; ")}"
          end

          @values = kwargs.compact.freeze
          freeze
        end

        # @return [Hash{Symbol => Object}] snake_case symbol keys, nil-valued
        #   optional fields omitted — exactly the shape the resource layer
        #   already accepts from hand-built hashes
        def to_h = @values.dup

        # @param name [Symbol, String] struct field name (snake_case) or wire key
        # @return [Object, nil]
        def [](name) = @values[name.to_s.underscore.to_sym]

        # @param key [Symbol, String]
        # @return [Boolean]
        def key?(key) = @values.key?(key.to_s.underscore.to_sym)

        # Returns a new struct with the given fields overridden. Keys may be
        # snake_case or camelCase. Revalidates.
        #
        # @param updates [Hash]
        # @return [DhanHQ::Contract::Params::Base]
        def merge(updates = {})
          merged = to_h.merge(updates.transform_keys { |k| k.to_s.underscore.to_sym })
          self.class.from_h(merged)
        end

        # @return [Boolean] true when the struct would pass the schema checks
        def valid?
          validate_kwargs(@values).empty?
        end

        # @return [Array<String>] current schema violations (empty when valid)
        def errors = validate_kwargs(@values)

        # @return [String]
        def inspect
          fields = @values.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
          "#<#{self.class.name} #{fields}>"
        end

        private

        def validate_kwargs(kwargs)
          errors = []
          kwargs.each_key do |key|
            next if self.class.fields.key?(key.to_s)

            errors << "unknown field `#{key}` (known: #{self.class.fields.keys.join(", ")})"
          end

          self.class.fields.each do |name, spec|
            value = kwargs[name.to_sym]
            if value.nil?
              errors << "missing required field `#{name}` (wire key `#{spec["wire_key"]}`)" if spec["required"]
              next
            end

            if (enm = spec["enum"]) && !enm.include?(value)
              errors << "field `#{name}` must be one of #{enm.join(", ")}, got #{value.inspect}"
            end
            next unless (typ = spec["type"]) && !type_matches?(typ, value)

            errors << "field `#{name}` must be #{typ}, got #{value.class}"
          end
          errors
        end

        # JSON-Schema type check. A type string may carry several alternatives
        # joined with "|" exactly as the generator emits them.
        def type_matches?(type, value)
          type.split("|").each do |candidate|
            case candidate
            when "string"   then return true if value.is_a?(String)
            when "integer"  then return true if value.is_a?(Integer)
            when "number"   then return true if value.is_a?(Numeric)
            when "boolean"  then return true if BOOLEAN_VALUES.include?(value)
            when "array"    then return true if value.is_a?(Array)
            when "object"   then return true if value.is_a?(Hash)
            else                 return true # unrecognised type: never block
            end
          end
          false
        end
      end
    end
  end
end
