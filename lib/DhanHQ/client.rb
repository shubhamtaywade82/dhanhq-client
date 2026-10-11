# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"
require "active_support/core_ext/hash/indifferent_access"
require_relative "errors"
require_relative "rate_limiter"

module DhanHQ
  # The `Client` class provides a wrapper for HTTP requests to interact with the DhanHQ API.
  # Responsible for:
  # - Establishing and managing the HTTP connection
  # - Handling authentication and request headers
  # - Sending raw HTTP requests (`GET`, `POST`, `PUT`, `DELETE`)
  # - Parsing JSON responses into HashWithIndifferentAccess
  # - Handling standard HTTP errors (400, 401, 403, etc.)
  # - Implementing **Rate Limiting** to avoid hitting API limits.
  #
  # It supports `GET`, `POST`, `PUT`, and `DELETE` requests with JSON encoding/decoding.
  # Credentials (`access_token`, `client_id`) are automatically added to each request.
  #
  # @see https://dhanhq.co/docs/v2/ DhanHQ API Documentation
  class Client
    include DhanHQ::RequestHelper
    include DhanHQ::ResponseHelper

    # Transient failures raised by this gem, worth retrying as-is.
    RETRYABLE_SDK_ERRORS = [
      DhanHQ::RateLimitError,
      DhanHQ::InternalServerError,
      DhanHQ::NetworkError
    ].freeze
    private_constant :RETRYABLE_SDK_ERRORS

    # Transport failures raised by Faraday. Also worth retrying, but they are not part
    # of this gem's error hierarchy, so a caller rescuing DhanHQ::Error would miss
    # them — they are translated on the way out. See {#exhausted_error}.
    RETRYABLE_TRANSPORT_ERRORS = [
      Faraday::TimeoutError,
      Faraday::ConnectionFailed
    ].freeze
    private_constant :RETRYABLE_TRANSPORT_ERRORS

    attr_reader :config, :token_manager, :api_type

    # Initializes a new DhanHQ Client with instance-level configuration and rate limiting.
    #
    # @param config_or_attrs [DhanHQ::Configuration, Hash, nil] Optional configuration or attribute hash
    # @param config [DhanHQ::Configuration, nil] Optional keyword configuration
    # @param api_type [Symbol] Type of API (`:order_api`, `:data_api`, `:non_trading_api`)
    # @param mode [Symbol, nil] Optional environment override (`:live`, `:sandbox`, `:hybrid`)
    #   for this client. When combined with +config:+ the configuration is forked,
    #   so a shared/global configuration is never mutated.
    # @param attrs [Hash] Additional keyword configuration attributes
    def initialize(config_or_attrs = nil, config: nil, api_type: :order_api, mode: nil, **attrs)
      attrs = attrs.merge(mode: mode) if mode
      @config = resolve_config(config_or_attrs, config, attrs)
      @api_type = api_type
      @rate_limiter = RateLimiter.for(api_type)

      raise DhanHQ::Error, "RateLimiter initialization failed" unless @rate_limiter
    end

    # The Faraday connection used for HTTP requests.
    # Built on first use and rebuilt whenever the base URL for this client's API
    # tier changes — including a mid-flight mode switch.
    #
    # @return [Faraday::Connection]
    def connection
      current_url = @config.base_url_for(@api_type)
      return @connection if @connection && @last_base_url == current_url

      @last_base_url = current_url
      @connection = build_connection(current_url)
    end

    # Resource accessors bound to this client instance. Each resource gets the client
    # matching its own API_TYPE, so e.g. option chain calls throttle at 1 per 3 sec
    # instead of borrowing the order client's 10/sec limiter.
    def orders = @orders ||= Resources::Orders.new(client: client_for(Resources::Orders::API_TYPE))
    def market_feed = @market_feed ||= Resources::MarketFeed.new(client: client_for(Resources::MarketFeed::API_TYPE))
    def positions = @positions ||= Resources::Positions.new(client: client_for(Resources::Positions::API_TYPE))
    def holdings = @holdings ||= Resources::Holdings.new(client: client_for(Resources::Holdings::API_TYPE))
    def historical_data = @historical_data ||= Resources::HistoricalData.new(client: client_for(Resources::HistoricalData::API_TYPE))
    def option_chain = @option_chain ||= Resources::OptionChain.new(client: client_for(Resources::OptionChain::API_TYPE))
    def funds = @funds ||= Resources::Funds.new(client: client_for(Resources::Funds::API_TYPE))
    def trades = @trades ||= Resources::Trades.new(client: client_for(Resources::Trades::API_TYPE))
    def forever_orders = @forever_orders ||= Resources::ForeverOrders.new(client: client_for(Resources::ForeverOrders::API_TYPE))
    def alert_orders = @alert_orders ||= Resources::AlertOrders.new(client: client_for(Resources::AlertOrders::API_TYPE))
    def iceberg_orders = @iceberg_orders ||= Resources::IcebergOrders.new(client: client_for(Resources::IcebergOrders::API_TYPE))
    def super_orders = @super_orders ||= Resources::SuperOrders.new(client: client_for(Resources::SuperOrders::API_TYPE))
    def twap_orders = @twap_orders ||= Resources::TwapOrders.new(client: client_for(Resources::TwapOrders::API_TYPE))
    def statements = @statements ||= Resources::Statements.new(client: client_for(Resources::Statements::API_TYPE))
    def kill_switch = @kill_switch ||= Resources::KillSwitch.new(client: client_for(Resources::KillSwitch::API_TYPE))
    def pnl_exit = @pnl_exit ||= Resources::PnlExit.new(client: client_for(Resources::PnlExit::API_TYPE))
    def trader_control = @trader_control ||= Resources::TraderControl.new(client: client_for(Resources::TraderControl::API_TYPE))
    def ip_setup = @ip_setup ||= Resources::IPSetup.new(client: client_for(Resources::IPSetup::API_TYPE))
    def edis = @edis ||= Resources::Edis.new(client: client_for(Resources::Edis::API_TYPE))
    def scanx = @scanx ||= Resources::ScanX.new(client: client_for(Resources::ScanX::API_TYPE))

    # The effective environment (+:live+ or +:sandbox+) for requests issued by
    # this client, resolved from its API tier and the configured mode.
    #
    # @return [Symbol]
    def environment
      @config.environment_for(@api_type)
    end

    # WebSocket streams bound to this client instance configuration
    def ws_market_feed(mode: :ticker, url: nil, &block)
      WS::Client.new(mode: mode, url: url, config: @config).tap do |ws|
        ws.start if block_given?
        ws.on(:tick, &block) if block_given?
      end
    end

    def ws_order_update = WS::Orders::Client.new(config: @config)
    def ws_market_depth = WS::MarketDepth::Client.new(config: @config)

    # Sends an HTTP request to the API with automatic retry for transient errors.
    #
    # @param method [Symbol] The HTTP method (`:get`, `:post`, `:put`, `:delete`)
    # @param path [String] The API endpoint path.
    # @param payload [Hash] The request parameters or body.
    # @param retries [Integer] Number of retries for transient errors (default: 3)
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>] Parsed JSON response.
    # @raise [DhanHQ::Error] If an HTTP error occurs.
    def request(method, path, payload, retries: 3)
      payload = with_correlation_id(method, path, payload)
      return dry_run.response_for(method, path, payload) if dry_run.simulates?(method, path)

      ensure_sandbox_supports!(method, path)

      @token_manager&.ensure_valid_token!
      @rate_limiter.throttle!

      effective_retries = retryable_write?(method, path) ? retries : 0

      with_auth_retry do
        with_transient_retry(retries: effective_retries) do
          response = connection.send(method, path) do |req|
            req.headers.merge!(build_headers(path))
            prepare_payload(req, payload, method, path)
          end
          handle_response(response)
        end
      end
    end

    def with_auth_retry
      yield
    rescue DhanHQ::InvalidAuthenticationError, DhanHQ::InvalidTokenError,
           DhanHQ::TokenExpiredError, DhanHQ::AuthenticationFailedError => e
      raise unless @config&.access_token_provider

      @config.on_token_expired&.call(e)
      DhanHQ.logger&.warn("[DhanHQ::Client] Auth failure (#{e.class}), retrying once with fresh token")
      yield
    end

    def with_transient_retry(retries:)
      attempt = 0
      begin
        yield
      rescue *RETRYABLE_SDK_ERRORS, *RETRYABLE_TRANSPORT_ERRORS => e
        attempt += 1
        raise exhausted_error(e, retries) if attempt > retries

        backoff = calculate_backoff(attempt)
        DhanHQ.logger&.warn(
          "[DhanHQ::Client] Transient failure (#{e.class}), retrying in #{backoff}s (attempt #{attempt}/#{retries})"
        )
        sleep(backoff)
        retry
      end
    end

    # Convenience wrapper for issuing a GET request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] Query parameters for the request.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def get(path, params = {})
      request(:get, path, params)
    end

    # Convenience wrapper for issuing a POST request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] JSON payload for the request.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def post(path, params = {})
      request(:post, path, params)
    end

    # Convenience wrapper for issuing a PUT request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] JSON payload for the request.
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def put(path, params = {})
      request(:put, path, params)
    end

    # Convenience wrapper for issuing a DELETE request.
    #
    # @param path [String] The API endpoint path.
    # @param params [Hash] Optional request payload (rare for DELETE).
    # @return [HashWithIndifferentAccess, Array<HashWithIndifferentAccess>]
    #   Parsed JSON response.
    # @see #request
    def delete(path, params = {})
      request(:delete, path, params)
    end

    def generate_access_token(dhan_client_id:, pin:, totp: nil, totp_secret: nil)
      token = Auth::TokenGenerator.new.generate(
        dhan_client_id: dhan_client_id,
        pin: pin,
        totp: totp,
        totp_secret: totp_secret
      )

      DhanHQ.configure do |config|
        config.access_token = token.access_token
        config.client_id = token.client_id if token.client_id.to_s.strip != ""
      end

      token
    end

    def renew_access_token
      token = Auth::TokenRenewal.new.renew

      DhanHQ.configure do |config|
        config.access_token = token.access_token
        config.client_id = token.client_id if token.client_id.to_s.strip != ""
      end

      token
    end

    def enable_auto_token_management!(dhan_client_id:, pin:, totp_secret:)
      @token_manager = Auth::TokenManager.new(
        dhan_client_id: dhan_client_id,
        pin: pin,
        totp_secret: totp_secret
      )

      @token_manager.generate!
    end

    # A client sharing this one's config but rate-limited for a different API tier.
    # RateLimiter.for(api_type) is a shared instance per type, so sibling clients still
    # throttle against the same counters as any other client using that tier.
    #
    # @param api_type [Symbol] Target API tier (:order_api, :data_api, :non_trading_api, :option_chain)
    # @return [DhanHQ::Client]
    def client_for(api_type)
      return self if api_type == @api_type

      @sibling_clients ||= {}
      @sibling_clients[api_type] ||= self.class.new(config: @config, api_type: api_type)
    end

    private

    # Credentials for this client's API tier: the sandbox pair when the tier
    # routes to the sandbox host, the production pair otherwise.
    def request_access_token
      @config.access_token_for(@api_type)
    end

    def request_client_id
      @config.client_id_for(@api_type)
    end

    # Fails fast when this request would hit the sandbox host on a path it does
    # not serve (see {Constants::SANDBOX_UNSUPPORTED_PATH_PREFIXES}), instead of
    # surfacing an opaque 404. Never falls back to production.
    def ensure_sandbox_supports!(method, path)
      return unless environment == :sandbox
      return unless Constants::SANDBOX_UNSUPPORTED_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }

      raise DhanHQ::SandboxUnsupportedError,
            "#{method.to_s.upcase} #{path} is not available on the Dhan sandbox (#{@config.mode} mode routes " \
            "#{@api_type} to it). For a read-only endpoint, route its tier to production with " \
            "environment_overrides (e.g. { #{@api_type}: :live }); order-placing endpoints have no sandbox equivalent."
    end

    def resolve_config(config_or_attrs, keyword_config, attrs = {})
      if config_or_attrs.is_a?(DhanHQ::Configuration)
        fork_config_with_attrs(config_or_attrs, attrs)
      elsif config_or_attrs.is_a?(Hash)
        DhanHQ::Configuration.new(config_or_attrs.merge(attrs))
      elsif keyword_config
        fork_config_with_attrs(keyword_config, attrs)
      elsif attrs.any?
        DhanHQ::Configuration.new(attrs)
      else
        DhanHQ.ensure_configuration!
      end
    end

    # Copies a Configuration when per-instance attributes (e.g. +mode:+) are
    # given alongside it, so an injected or global configuration is never
    # mutated. Without extra attributes the original object is shared unchanged.
    def fork_config_with_attrs(config, attrs)
      return config if attrs.empty?

      config.dup.tap do |forked|
        attrs.each { |key, value| forked.public_send("#{key}=", value) }
      end
    end

    # Simulator that answers state-changing requests locally when dry run is on.
    #
    # @return [DhanHQ::DryRun::Simulator]
    def dry_run
      @dry_run ||= DhanHQ::DryRun::Simulator.new(config: @config)
    end

    # A write may be auto-retried only when the user has explicitly opted in.
    def retryable_write?(method, path)
      return true unless WritePaths.mutating?(method, path)

      @config&.retry_non_idempotent_writes? || false
    end

    # Fills in a +correlationId+ on order placements that lack one, so a caller who
    # hits a timeout can still discover whether the order reached the exchange via
    # GET /v2/orders/external/{correlation-id}.
    def with_correlation_id(method, path, payload)
      return payload unless WritePaths.order_placement?(method, path)
      return payload unless payload.is_a?(Hash)
      return payload unless @config&.auto_correlation_id?
      return payload if correlation_id?(payload)

      inject_correlation_id(payload)
    end

    # Keys a caller may already have used for the correlation id, in either casing.
    CORRELATION_ID_KEYS = %i[correlationId correlation_id].flat_map { |key| [key, key.to_s] }.freeze
    private_constant :CORRELATION_ID_KEYS

    # @return [Boolean] True when the caller supplied their own correlation id.
    def correlation_id?(payload)
      CORRELATION_ID_KEYS.any? { |key| payload.key?(key) }
    end

    # Returns a copy of the payload carrying a generated correlation id, matching the
    # key type the payload already uses.
    def inject_correlation_id(payload)
      correlation_id = "dhq-#{SecureRandom.hex(8)}"
      out = payload.dup
      out.keys.any?(String) ? out["correlationId"] = correlation_id : out[:correlationId] = correlation_id
      out
    end

    # The exception to raise once the retries are spent.
    #
    # Faraday's transport errors are translated to {DhanHQ::NetworkError}, so a caller
    # rescuing DhanHQ::Error sees every failure this client can produce. This gem's own
    # errors already belong to that hierarchy and are re-raised unchanged.
    #
    # @param error [StandardError] The failure that exhausted the retries.
    # @param retries [Integer] How many retries were allowed.
    # @return [StandardError] The exception to raise.
    def exhausted_error(error, retries)
      return error unless RETRYABLE_TRANSPORT_ERRORS.any? { |klass| error.is_a?(klass) }

      attempts = retries.zero? ? "" : " after #{retries} retries"
      DhanHQ::NetworkError.new("Request failed#{attempts}: #{error.message}")
    end

    def build_connection(url)
      # Get timeout values from configuration or environment, with sensible defaults
      connect_timeout = ENV.fetch("DHAN_CONNECT_TIMEOUT", 10).to_i
      read_timeout = ENV.fetch("DHAN_READ_TIMEOUT", 30).to_i
      write_timeout = ENV.fetch("DHAN_WRITE_TIMEOUT", 30).to_i

      Faraday.new(url: url) do |conn|
        conn.request :url_encoded
        conn.options.timeout = read_timeout
        conn.options.open_timeout = connect_timeout
        conn.options.write_timeout = write_timeout
        conn.adapter Faraday.default_adapter
      end
    end

    # Calculates exponential backoff time
    #
    # @param attempt [Integer] Current attempt number (1-based)
    # @return [Float] Backoff time in seconds
    def calculate_backoff(attempt)
      # Exponential backoff: 1s, 2s, 4s, 8s, etc., capped at 30s
      [2**(attempt - 1), 30].min.to_f
    end
  end
end
