# frozen_string_literal: true

require "faraday"
require "json"
require "active_support/core_ext/hash/indifferent_access"
require_relative "errors"

module DhanHQ
  # The `Client` class provides a wrapper for HTTP requests to interact with the DhanHQ API.
  #
  # It supports `GET`, `POST`, `PUT`, and `DELETE` requests with JSON encoding/decoding.
  # Credentials (`access_token`, `client_id`) are automatically added to each request.
  #
  # @see https://dhanhq.co/docs/v2/ DhanHQ API Documentation
  class Client
    ERROR_MAPPING = {
      "DH-901" => DhanHQ::InvalidAuthenticationError,
      "DH-902" => DhanHQ::InvalidAccessError,
      "DH-903" => DhanHQ::UserAccountError,
      "DH-904" => DhanHQ::RateLimitError,
      "DH-905" => DhanHQ::InputExceptionError,
      "DH-906" => DhanHQ::OrderError,
      "DH-907" => DhanHQ::DataError,
      "DH-908" => DhanHQ::InternalServerError,
      "DH-909" => DhanHQ::NetworkError,
      "DH-910" => DhanHQ::OtherError,
      "800" => DhanHQ::InternalServerError,
      "804" => DhanHQ::Error,                   # Too many instruments
      "805" => DhanHQ::RateLimitError,          # Too many requests
      "806" => DhanHQ::DataError, # Data API not subscribed
      "807" => DhanHQ::InvalidTokenError, # Token expired
      "808" => DhanHQ::AuthenticationFailedError, # Auth failed
      "809" => DhanHQ::InvalidTokenError,       # Invalid token
      "810" => DhanHQ::InvalidClientIDError,    # Invalid Client ID
      "811" => DhanHQ::InvalidRequestError,     # Invalid expiry date
      "812" => DhanHQ::InvalidRequestError,     # Invalid date format
      "813" => DhanHQ::InvalidRequestError,     # Invalid security ID
      "814" => DhanHQ::InvalidRequestError      # Invalid request
    }.freeze

    # The Faraday connection object used for HTTP requests.
    #
    # @return [Faraday::Connection] The connection instance used for API requests.
    attr_reader :connection

    # Initializes a new DhanHQ Client instance.
    #
    # @example Create a new client:
    #   client = DhanHQ::Client.new
    #
    # @return [DhanHQ::Client] A new client instance configured for API requests.
    def initialize
      @connection = Faraday.new(url: DhanHQ.configuration.base_url) do |conn|
        conn.request :json
        conn.response :json, content_type: /\bjson$/
        conn.response :logger if ENV["DHAN_DEBUG"] == "true"
        conn.adapter Faraday.default_adapter
      end
    end

    # Sends an HTTP request to the API.
    #
    # @param method [Symbol] The HTTP method (e.g., :get, :post, :put, :delete).
    # @param path [String] The API endpoint path.
    # @param payload [Hash] The parameters or body for the request.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response indicates an error.
    def request(method, path, payload)
      response = connection.send(method) do |req|
        req.url path
        req.headers.merge!(build_headers(path))
        prepare_payload(req, payload, method)
      end
      handle_response(response)
    end

    # # Sends a GET request to the API.
    # #
    # # @param path [String] The API endpoint path.
    # # @param params [Hash] The query parameters for the GET request.
    # # @return [Hash, Array] The parsed JSON response.
    # # @raise [DhanHQ::Error] If the response indicates an error.
    # def get(path, params = {})
    #   request(:get, path, params)
    # end

    # # Sends a POST request to the API.
    # #
    # # @param path [String] The API endpoint path.
    # # @param body [Hash] The body of the POST request.
    # # @return [Hash, Array] The parsed JSON response.
    # # @raise [DhanHQ::Error] If the response indicates an error.
    # def post(path, body = {})
    #   request(:post, path, body)
    # end

    # # Sends a PUT request to the API.
    # #
    # # @param path [String] The API endpoint path.
    # # @param body [Hash] The body of the PUT request.
    # # @return [Hash, Array] The parsed JSON response.
    # # @raise [DhanHQ::Error] If the response indicates an error.
    # def put(path, body = {})
    #   request(:put, path, body)
    # end

    # # Sends a DELETE request to the API.
    # #
    # # @param path [String] The API endpoint path.
    # # @param params [Hash] The query parameters for the DELETE request.
    # # @return [Hash, Array] The parsed JSON response.
    # # @raise [DhanHQ::Error] If the response indicates an error.
    # def delete(path, params = {})
    #   request(:delete, path, params)
    # end

    private

    # Dynamically builds headers for the request
    def build_headers(path)
      headers = {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "access-token" => DhanHQ.configuration.access_token
      }

      # Add client-id for DATA APIs
      headers["client-id"] = DhanHQ.configuration.client_id if data_api?(path)

      headers
    end

    # def format_params(path, params)
    #   return params unless params.is_a?(Hash)

    #   if optionchain_api?(path)
    #     titleize_keys(params)
    #   else
    #     camelize_keys(params)
    #   end
    # end

    # Check if the path belongs to a DATA API
    def data_api?(path)
      data_api_paths = [
        "/v2/marketfeed/ltp",
        "/v2/marketfeed/ohlc",
        "/v2/marketfeed/quote",
        "/v2/optionchain",
        "/v2/optionchain/expirylist"
      ]
      data_api_paths.any? { |data_path| path.start_with?(data_path) }
    end

    # def camelize_keys(hash)
    #   hash.transform_keys { |key| key.to_s.camelize(:lower) }
    # end

    # def titleize_keys(hash)
    #   hash.transform_keys { |key| key.to_s.titleize.delete(" ") }
    # end

    # def optionchain_api?(path)
    #   path.include?("/optionchain")
    # end

    # Prepares the request payload.
    #
    # @param req [Faraday::Request] The request object.
    # @param payload [Hash] The payload for the request.
    # @param method [Symbol] The HTTP method.
    # @return [void]
    def prepare_payload(req, payload, method)
      return if payload.nil? || payload.empty?

      unless payload.is_a?(Hash)
        raise DhanHQ::InputExceptionError,
              "Invalid payload: Expected a Hash, got #{payload.class}"
      end

      case method
      when :delete then req.params = {}
      when :get then req.params = payload
      else req.body = payload.to_json
      end
    end
    # def prepare_payload(req, payload, method)
    #   return if payload.nil? || payload.empty?

    #   unless payload.is_a?(Hash)
    #     raise DhanHQ::InputExceptionError, "Invalid payload: Expected a Hash, got #{payload.class}"
    #   end

    #   formatted_payload = format_params(req.path, payload)

    #   case method
    #   when :delete
    #     req.params = {}
    #   when :get
    #     req.params = formatted_payload
    #   else
    #     unless formatted_payload&.key?(:dhanClientId)
    #       formatted_payload[:dhanClientId] ||= DhanHQ.configuration.client_id
    #     end
    #     req.body = formatted_payload.to_json
    #   end
    # end

    # Handles the API response.
    #
    # @param response [Faraday::Response] The response object.
    # @return [Hash, Array] The parsed JSON response.
    # @raise [DhanHQ::Error] If the response status indicates an error.
    def handle_response(response)
      case response.status
      when 200..299
        symbolize_keys(response.body)
      else
        handle_error(response)
      end
    end

    # Handles errors in the API response.
    #
    # @param response [Faraday::Response] The response object.
    # @return [void]
    # @raise [DhanHQ::Error] The specific error based on the response status or error code.
    def handle_error(response)
      body = symbolize_keys(response.body)
      error_code = body[:errorCode] || response.status
      error_message = "#{response.status}: #{body[:error] || body[:message] || response.body}"

      if ERROR_MAPPING.key?(error_code)
        raise ERROR_MAPPING[error_code],
              "#{ERROR_MAPPING[error_code].name.split("::").last.gsub("Error", "")}: #{error_message}"
      end

      case response.status
      when 400 then raise DhanHQ::InputExceptionError, "Bad Request: #{error_message}"
      when 401 then raise DhanHQ::InvalidAuthenticationError, "Unauthorized: #{error_message}"
      when 403 then raise DhanHQ::InvalidAccessError, "Forbidden: #{error_message}"
      when 404 then raise DhanHQ::NotFoundError, "Not Found: #{error_message}"
      when 429 then raise DhanHQ::RateLimitError, "Rate Limit Exceeded: #{error_message}"
      when 500..599 then raise DhanHQ::InternalServerError, "Server Error: #{error_message}"
      else
        raise DhanHQ::OtherError, "Unknown Error: #{error_message}"
      end
    end

    # Converts response body to a hash or array with indifferent access.
    #
    # @param body [String, Hash, Array] The response body.
    # @return [Hash, Array] The response body as a hash/array with indifferent access.
    def symbolize_keys(body)
      parsed_body =
        if body.is_a?(String)
          begin
            JSON.parse(body, symbolize_names: true)
          rescue JSON::ParserError
            {} # Return an empty hash if the string is not valid JSON
          end
        else
          body
        end

      if parsed_body.is_a?(Hash)
        parsed_body.with_indifferent_access
      elsif parsed_body.is_a?(Array)
        parsed_body.map(&:with_indifferent_access)
      else
        parsed_body
      end
    end
  end
end
