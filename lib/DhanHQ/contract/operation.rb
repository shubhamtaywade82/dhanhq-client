# frozen_string_literal: true

module DhanHQ
  module Contract
    # One API operation from the contract, normalised for the gem's needs.
    #
    # Instances are frozen and created only by {Registry}; every field is
    # derived from the vendored OpenAPI documents (plus overlays), never from
    # hand-transcribed knowledge.
    class Operation
      # Parameter-key casing behaviour the wire expects for this operation.
      # Derived from the gem's established behaviour (BaseAPI param formatting),
      # now declared per operation instead of sniffed from the URL.
      PARAM_STYLES = {
        "marketfeedLTP" => :none,           # POST /marketfeed/ltp passes keys through
        "marketfeedOHLC" => :none,
        "marketfeedQuote" => :none,
        "optionchain" => :titleize,         # POST /optionchain sends Titleized keys
        "optionchainexpirylist" => :titleize
      }.freeze
      DEFAULT_PARAM_STYLE = :camelize

      attr_reader :id, :verb, :path, :summary, :docs_only, :rate_limit_class,
                  :request_schema_name, :response_schema_names, :sandbox_supported,
                  :quirks, :docs_url

      # @param id [String] operationId
      # @param verb [Symbol] HTTP verb
      # @param path [String] OpenAPI path template (e.g. "/orders/{order-id}")
      # @param summary [String, nil]
      # @param docs_only [Boolean] true when the operation comes from an overlay
      #   because the vendor spec omits a documented endpoint
      # @param rate_limit_class [Symbol, nil] tier key into RateLimiter::RATE_LIMITS
      # @param request_schema_name [String, nil] component schema name of the request body
      # @param response_schema_names [Array<String>] component schema names of 2xx responses
      # @param sandbox_supported [Boolean] whether the sandbox spec serves this operation
      # @param quirks [Array<String>, nil] sandbox behaviour notes (overlay 0003)
      # @param docs_url [String, nil] prose docs URL for docs-only operations
      def initialize(id:, verb:, path:, summary: nil, docs_only: false,
                     rate_limit_class: nil, request_schema_name: nil,
                     response_schema_names: [], sandbox_supported: false,
                     quirks: nil, docs_url: nil)
        @id = id
        @verb = verb
        @path = path
        @summary = summary
        @docs_only = docs_only
        @rate_limit_class = rate_limit_class&.to_sym
        @request_schema_name = request_schema_name
        @response_schema_names = response_schema_names.freeze
        @sandbox_supported = sandbox_supported
        @quirks = quirks&.freeze
        @docs_url = docs_url
        @wildcard_count = @path.scan(/\{[^}]+\}/).size
        @path_regexp = build_path_regexp
        freeze
      end

      def docs_only? = @docs_only
      def sandbox_supported? = @sandbox_supported

      # @return [Symbol] How BaseAPI should format request keys for this operation
      def param_style
        PARAM_STYLES.fetch(id, DEFAULT_PARAM_STYLE)
      end

      # @return [Hash, nil] The request body schema (dereferenced from the live doc)
      def request_schema
        return nil unless @request_schema_name

        Registry.live_schemas[@request_schema_name]
      end

      # @return [Array<String>] Required property names of the request body
      def request_required
        request_schema&.fetch("required", [])&.map(&:to_s) || []
      end

      # @return [Hash, nil] A 2xx response schema by name (dereferenced)
      def response_schema(name)
        return nil unless name && Registry.live_schemas[name]

        Registry.live_schemas[name]
      end

      # @return [String] Human label, e.g. "POST /orders (placeorder)"
      def label
        "#{verb.to_s.upcase} #{path} (#{id})"
      end

      # @return [Regexp] Matcher for concrete request paths
      def path_regexp
        @path_regexp
      end

      # Number of templated segments — used to prefer literal matches.
      def wildcard_count
        @wildcard_count
      end

      private

      def build_path_regexp
        source = @path.split("/").map do |segment|
          segment.start_with?("{") ? "[^/]+" : Regexp.escape(segment)
        end.join("/")
        Regexp.new("\\A#{source}\\z")
      end
    end
  end
end
