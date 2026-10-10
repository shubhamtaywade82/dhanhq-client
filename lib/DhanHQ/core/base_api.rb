# frozen_string_literal: true

module DhanHQ
  # Base class for all API resource classes.
  # Delegates HTTP requests to {DhanHQ::Client} and exposes helpers shared by
  # resource wrappers.
  class BaseAPI
    include DhanHQ::APIHelper
    include DhanHQ::AttributeHelper

    # Default API type used when a subclass does not override {#initialize}.
    API_TYPE = :non_trading_api
    # Root path prepended to each endpoint segment.
    HTTP_PATH = ""

    attr_reader :client

    # Initializes the BaseAPI with the appropriate Client instance
    #
    # @param client [DhanHQ::Client, nil] Optional injected client instance
    # @param api_type [Symbol] API type (`:order_api`, `:data_api`, `:non_trading_api`)
    def initialize(client: nil, api_type: self.class::API_TYPE)
      @client = client || DhanHQ::Client.new(api_type: api_type)
    end

    # Perform a GET request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Query parameters
    # @return [Hash, Array] The parsed API response
    def get(endpoint, params: {})
      formatted_params = format_params(:get, endpoint, params)
      handle_response(client.get(build_path(endpoint), formatted_params))
    end

    # Perform a POST request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def post(endpoint, params: {})
      formatted_params = format_params(:post, endpoint, params)
      handle_response(client.post(build_path(endpoint), formatted_params))
    end

    # Perform a PUT request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @param params [Hash] Request body
    # @return [Hash, Array] The parsed API response
    def put(endpoint, params: {})
      formatted_params = format_params(:put, endpoint, params)
      handle_response(client.put(build_path(endpoint), formatted_params))
    end

    # Perform a DELETE request via `Client`
    #
    # @param endpoint [String] API endpoint
    # @return [Hash, Array] The parsed API response
    def delete(endpoint)
      formatted_params = format_params(:delete, endpoint, {})
      handle_response(client.delete(build_path(endpoint), formatted_params))
    end

    private

    # Construct the complete API URL
    #
    # @param endpoint [String] API endpoint
    # @return [String] Full API path
    def build_path(endpoint)
      "#{self.class::HTTP_PATH}#{endpoint}"
    end

    # Format parameters based on API endpoint. The parameter key style is
    # declared per operation in the vendored contract (DhanHQ::Contract::Operation::PARAM_STYLES)
    # and resolved through the registry; the path-based strategy below is only
    # the legacy fallback for paths the contract does not cover.
    #
    # Generated param structs (DhanHQ::Contract::Params) are coerced to plain
    # hashes here, so every resource method transparently accepts either a
    # hash or a struct.
    def format_params(verb, endpoint, params)
      params = contract_params(params)
      full_path = build_path(endpoint)
      return params if params.empty?

      param_formatter_for(verb, full_path).call(params)
    end

    # Coerces a generated param struct to its wire hash. Idempotent: hashes
    # (and anything else) pass through untouched.
    def contract_params(params)
      DhanHQ::Contract::Params.coerce(params)
    end

    # Returns a callable that formats params for the given verb + path (Strategy).
    def param_formatter_for(verb, full_path)
      style = contract_param_style(verb, full_path)
      return ->(p) { p } if style == :none
      return ->(p) { titleize_keys(p) } if style == :titleize

      ->(p) { camelize_keys(p) }
    end

    # @return [Symbol] The parameter key style for this verb + path: the
    #   contract-declared one when an operation matches, else the legacy
    #   URL-sniffed strategy for paths absent from the contract.
    def contract_param_style(verb, full_path)
      DhanHQ::Contract::Registry.resolve(verb, full_path)&.param_style ||
        legacy_param_style(full_path)
    end

    # Legacy casing strategy for paths the contract does not cover (kept for
    # behaviour compatibility; the conformance suite keeps the bound surface
    # complete, so this only serves unbound legacy paths).
    def legacy_param_style(full_path)
      return :none if full_path.include?("/marketfeed")
      return :titleize if full_path.include?("/optionchain")

      :camelize
    end
  end
end
