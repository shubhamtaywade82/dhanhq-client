# frozen_string_literal: true

require "json"
require "logger"
require "zeitwerk"
require "dotenv/load"
# Minimal eager requires for backward-compatible constants.
# These are widely referenced (e.g. `DhanHQ::BaseAPI`) and should not depend on
# the autoloader being fully configured.
require_relative "DhanHQ/helpers/api_helper"
require_relative "DhanHQ/helpers/attribute_helper"
require_relative "DhanHQ/helpers/validation_helper"
require_relative "DhanHQ/helpers/request_helper"
require_relative "DhanHQ/helpers/response_helper"
require_relative "DhanHQ/core/base_api"
require_relative "DhanHQ/core/base_model"
require_relative "DhanHQ/core/base_resource"

# The top-level module for the DhanHQ client library.
#
# Provides configuration management for setting credentials and API-related settings.
module DhanHQ
  LOADER = Zeitwerk::Loader.new
  LOADER.tag = "dhanhq"
  LOADER.inflector.inflect(
    "api_helper" => "APIHelper",
    "auth_api" => "AuthAPI",
    "base_api" => "BaseAPI",
    "ip_setup" => "IPSetup",
    "json_loader" => "JSONLoader",
    "ws" => "WS"
  )
  LOADER.push_dir(File.join(__dir__, "DhanHQ"), namespace: self)
  LOADER.push_dir(File.join(__dir__, "dhanhq"), namespace: self)
  LOADER.collapse(File.join(__dir__, "DhanHQ", "core"))
  LOADER.collapse(File.join(__dir__, "DhanHQ", "helpers"))
  LOADER.collapse(File.join(__dir__, "dhanhq", "analysis", "helpers"))
  LOADER.ignore(
    File.join(__dir__, "DhanHQ", "errors.rb"),
    File.join(__dir__, "DhanHQ", "version.rb")
  )
  LOADER.setup

  class Error < StandardError; end

  class << self
    # Default REST API host used when no custom base URL is provided.
    #
    # @return [String]
    BASE_URL = "https://api.dhan.co/v2"
    # The current configuration instance.
    #
    # @return [DhanHQ::Configuration, nil] The current configuration or `nil` if not set.
    attr_accessor :configuration

    attr_writer :logger

    # Configures the DhanHQ client with user-defined settings.
    #
    # @example
    #   DhanHQ.configure do |config|
    #     config.access_token = 'your_access_token'
    #     config.client_id = 'your_client_id'
    #   end
    #
    # @yieldparam [DhanHQ::Configuration] configuration The configuration object.
    # @return [void]
    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
      self.logger ||= Logger.new($stdout, level: Logger::INFO)
    end

    # default logger so calls like DhanHQ.logger&.info never explode
    # Accessor for the logger instance used by the SDK.
    #
    # @return [Logger] The configured logger, defaulting to STDOUT at INFO level.
    def logger
      @logger ||= Logger.new($stdout, level: Logger::INFO)
    end

    # Configures the DhanHQ client using environment variables.
    #
    # When credentials are injected via `DHAN_ACCESS_TOKEN` and `DHAN_CLIENT_ID` this helper
    # can be used to initialise a configuration without a block.
    #
    # @example
    #   DhanHQ.configure_with_env
    #
    # @return [void]
    def configure_with_env
      self.configuration ||= Configuration.new
      configuration.access_token = ENV.fetch("DHAN_ACCESS_TOKEN", nil)
      configuration.client_id = ENV.fetch("DHAN_CLIENT_ID", nil)
      configuration.base_url = ENV.fetch("DHAN_BASE_URL", BASE_URL)
      configuration.ws_version = ENV.fetch("DHAN_WS_VERSION", configuration.ws_version || 2).to_i
      configuration.ws_order_url = ENV.fetch("DHAN_WS_ORDER_URL", configuration.ws_order_url)
      configuration.ws_user_type = ENV.fetch("DHAN_WS_USER_TYPE", configuration.ws_user_type)
      configuration.partner_id = ENV.fetch("DHAN_PARTNER_ID", configuration.partner_id)
      configuration.partner_secret = ENV.fetch("DHAN_PARTNER_SECRET", configuration.partner_secret)
    end

    # Configures the DhanHQ client by fetching credentials from a token endpoint.
    #
    # Performs GET <base_url>/auth/dhan/token with Authorization: Bearer <bearer_token>.
    # Expects JSON with at least +access_token+ and +client_id+. Optional +base_url+ in
    # the response overrides the Dhan API base URL.
    #
    # @param base_url [String, nil] Base URL of your app (e.g. https://myapp.com). If nil, uses ENV["DHAN_TOKEN_ENDPOINT_BASE_URL"].
    # @param bearer_token [String, nil] Secret token for the endpoint. If nil, uses ENV["DHAN_TOKEN_ENDPOINT_BEARER"].
    # @return [DhanHQ::Configuration] The configured configuration.
    # @raise [DhanHQ::TokenEndpointError] On HTTP error or when response lacks access_token/client_id.
    #
    # @example Explicit
    #   DhanHQ.configure_from_token_endpoint(base_url: "https://myapp.com", bearer_token: "secret-token")
    #
    # @example From ENV (DHAN_TOKEN_ENDPOINT_BASE_URL and DHAN_TOKEN_ENDPOINT_BEARER set)
    #   DhanHQ.configure_from_token_endpoint
    def configure_from_token_endpoint(base_url: nil, bearer_token: nil)
      base_url ||= ENV.fetch("DHAN_TOKEN_ENDPOINT_BASE_URL", nil)
      bearer_token ||= ENV.fetch("DHAN_TOKEN_ENDPOINT_BEARER", nil)

      raise TokenEndpointError, "base_url and bearer_token (or ENV DHAN_TOKEN_ENDPOINT_*) are required" if base_url.to_s.empty? || bearer_token.to_s.empty?

      url = "#{base_url.to_s.chomp("/")}/auth/dhan/token"
      conn = Faraday.new(url: url) do |c|
        c.response :json, content_type: /\bjson$/
        c.adapter Faraday.default_adapter
      end

      response = conn.get("") do |req|
        req.headers["Authorization"] = "Bearer #{bearer_token}"
        req.headers["Accept"] = "application/json"
      end

      unless response.success?
        body = if response.body.is_a?(Hash)
                 response.body
               else
                 begin
                   JSON.parse(response.body.to_s)
                 rescue StandardError
                   {}
                 end
               end
        msg = body["error"] || body["message"] || body["errorMessage"] || response.body.to_s
        raise TokenEndpointError, "Token endpoint returned #{response.status}: #{msg}"
      end

      data = if response.body.is_a?(Hash)
               response.body
             else
               begin
                 JSON.parse(response.body.to_s)
               rescue StandardError
                 {}
               end
             end
      data = data.transform_keys(&:to_s) if data.is_a?(Hash)

      access_token = data["access_token"] || data[:access_token]
      client_id = data["client_id"] || data[:client_id]
      raise TokenEndpointError, "Token endpoint response missing access_token or client_id" if access_token.to_s.empty? || client_id.to_s.empty?

      self.configuration ||= Configuration.new
      configuration.access_token = access_token.to_s
      configuration.client_id = client_id.to_s
      dhan_base = data["base_url"] || data[:base_url]
      configuration.base_url = dhan_base.to_s if dhan_base.to_s != ""
      configuration
    end
  end
end
