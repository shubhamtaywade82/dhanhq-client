# frozen_string_literal: true

module DhanHQ
  # The `Configuration` class manages API credentials and settings.
  #
  # Use this class to set the required `access_token` and `client_id`, as well as optional
  # settings such as the base URL and CSV URLs.
  #
  # @see https://dhanhq.co/docs/v2/ DhanHQ API Documentation
  class Configuration
    # Default REST API host used when the base URL is not overridden.
    # @return [String]
    BASE_URL = Constants::Urls::REST_API_BASE

    # Default Sandbox API host.
    # @return [String]
    SANDBOX_URL = Constants::Urls::SANDBOX_API_BASE
    # The client ID for API authentication.
    # @return [String, nil] The client ID or `nil` if not set.
    attr_accessor :client_id

    # The access token for API authentication.
    # @return [String, nil] The access token or `nil` if not set.
    attr_accessor :access_token

    # Optional callable (Proc/lambda) that returns the access token at request time.
    # When set, {#resolved_access_token} calls this instead of using {#access_token}.
    # @return [Proc, nil]
    attr_accessor :access_token_provider

    # Optional callable invoked when the API returns 401/token-expired and the client
    # is about to retry (when {#access_token_provider} is set). Use for logging or
    # refreshing token in your store before the retry fetches a new token.
    # @return [Proc, nil]
    attr_accessor :on_token_expired

    # The base URL for API requests.
    # @return [String]
    attr_writer :base_url

    # Whether to use the sandbox environment.
    attr_accessor :sandbox

    # When true, state-changing requests (order placement, modification,
    # cancellation, position exits, trading controls) are validated and logged but
    # never sent to the API — the client answers with a simulated response instead.
    #
    # Read-only requests still hit the API, so market data, the option chain,
    # positions and holdings remain live. That makes dry-run usable for a full
    # strategy rehearsal against real prices.
    #
    # Set via +DHAN_DRY_RUN=true+ or in {DhanHQ.configure}.
    # @return [Boolean]
    attr_accessor :dry_run

    # Whether to auto-retry non-idempotent writes (order placement, modification,
    # cancellation) after a transient failure — a 429, a 5xx, or a network timeout.
    #
    # Defaults to +false+, because the DhanHQ API has no idempotency key: a POST
    # /v2/orders that times out may well have reached the exchange, and retrying it
    # can place a second, duplicate order. With this off, the transient error is
    # raised to the caller, who can reconcile using the correlation id (see
    # {#auto_correlation_id} and +DhanHQ::Models::Order.find_by_correlation+)
    # before deciding to resubmit.
    #
    # Read requests are always retried regardless of this setting.
    #
    # Set via +DHAN_RETRY_WRITES=true+ or in {DhanHQ.configure}.
    # @return [Boolean]
    attr_accessor :retry_non_idempotent_writes

    # Whether to log a deprecation notice, once per call site, when a non-bang write
    # method reports failure through +nil+, +false+ or a {DhanHQ::ErrorObject}.
    #
    # Those contracts disagree today and will unify on {DhanHQ::ErrorObject} in 4.0.0,
    # which is truthy — so an `if result` failure branch written against +nil+ or
    # +false+ will silently invert. The notice names the call sites that need moving to
    # a bang variant before then.
    #
    # Defaults to +true+: a notice nobody sees finds nothing. Set to +false+ once the
    # call sites are migrated, or via +DHAN_WARN_AMBIGUOUS_WRITE_FAILURE=false+.
    # @return [Boolean]
    attr_accessor :warn_on_ambiguous_write_failure

    # Whether to generate a +correlationId+ for order placements that do not carry
    # one. The correlation id is the only way to answer "did my order actually go
    # through?" after a timeout, via GET /v2/orders/external/{correlation-id}.
    #
    # Defaults to +false+ because it changes the request body, which would break
    # callers matching recorded fixtures on the exact payload. Turn it on to get
    # timeout-reconcilable orders for free. Only fills the field when absent; an
    # explicit correlation id is always preserved.
    #
    # Set via +DHAN_AUTO_CORRELATION_ID=true+ or in {DhanHQ.configure}.
    # @return [Boolean]
    attr_accessor :auto_correlation_id

    # URL for the compact CSV format of instruments.
    # @return [String] URL for compact CSV.
    attr_accessor :compact_csv_url

    # URL for the detailed CSV format of instruments.
    # @return [String] URL for detailed CSV.
    attr_accessor :detailed_csv_url

    # Websocket API version.
    # @return [Integer]
    attr_accessor :ws_version

    # Websocket order updates endpoint.
    # Sandbox does not support WebSocket; always returns production URL unless overridden.
    # @return [String]
    def ws_order_url
      @ws_order_url || Constants::Urls::WS_ORDER_UPDATE
    end

    # Websocket market feed endpoint.
    # Sandbox does not support WebSocket; always returns production URL unless overridden.
    # @return [String]
    def ws_market_feed_url
      @ws_market_feed_url || Constants::Urls::WS_MARKET_FEED
    end

    # Websocket market depth endpoint.
    # Sandbox does not support WebSocket; always returns production URL unless overridden.
    # @return [String]
    def ws_market_depth_url
      @ws_market_depth_url || Constants::Urls::WS_DEPTH_20
    end

    # Market depth level (20 or 200).
    # @return [Integer]
    attr_accessor :market_depth_level

    # When true, every raw inbound WebSocket frame (market feed, order updates,
    # market depth) is logged as a hex dump at debug level before it's parsed.
    # Off by default -- high volume, and the check happens before any hex
    # encoding work so there's no cost when disabled.
    #
    # Set via +DHAN_WS_DEBUG=true+ or in {DhanHQ.configure}.
    # @return [Boolean]
    attr_accessor :ws_debug

    # Setters for websocket URLs
    attr_writer :ws_order_url, :ws_market_feed_url, :ws_market_depth_url

    # Websocket user type for order updates.
    # @return [String] "SELF" or "PARTNER".
    attr_accessor :ws_user_type

    # Partner ID for order updates when `ws_user_type` is "PARTNER".
    # @return [String, nil]
    attr_accessor :partner_id

    # Partner secret for order updates when `ws_user_type` is "PARTNER".
    # @return [String, nil]
    attr_accessor :partner_secret

    # Returns the access token to use for this request.
    # If {#access_token_provider} is set, calls it (no memoization; token per request).
    # Otherwise returns {#access_token}.
    # @return [String]
    # @raise [DhanHQ::AuthenticationError] if provider returns nil/empty or no token is set.
    def resolved_access_token
      if access_token_provider
        token = access_token_provider.call
        raise DhanHQ::AuthenticationError, "access_token_provider returned nil or empty" if token.nil? || token.to_s.empty?

        token.to_s
      else
        access_token
      end
    end

    # Returns the base URL to use. If {#sandbox} is true and {#base_url}
    # is nil or the default production URL, returns {SANDBOX_URL}.
    # @return [String]
    def base_url
      if sandbox? && (@base_url.nil? || @base_url == BASE_URL)
        SANDBOX_URL
      else
        @base_url || BASE_URL
      end
    end

    def sandbox?
      @sandbox == true
    end

    # @return [Boolean] True when state-changing requests should be simulated.
    def dry_run?
      @dry_run == true
    end

    # @return [Boolean] True when non-idempotent writes may be auto-retried.
    def retry_non_idempotent_writes?
      @retry_non_idempotent_writes == true
    end

    # @return [Boolean] True when ambiguous write failures should be reported.
    def warn_on_ambiguous_write_failure?
      @warn_on_ambiguous_write_failure == true
    end

    # @return [Boolean] True when a correlation id should be generated for orders.
    def auto_correlation_id?
      @auto_correlation_id == true
    end

    # @return [Boolean] True when raw WebSocket frames should be hex-logged.
    def ws_debug?
      @ws_debug == true
    end

    # Initializes a new configuration instance with default values.
    #
    # @example
    #   config = DhanHQ::Configuration.new
    #   config.client_id = "your_client_id"
    #   config.access_token = "your_access_token"
    def initialize
      @client_id = ENV.fetch("DHAN_CLIENT_ID", nil)
      @access_token = ENV.fetch("DHAN_ACCESS_TOKEN", nil)
      @sandbox        = env_flag("DHAN_SANDBOX", default: false)
      @dry_run        = env_flag("DHAN_DRY_RUN", default: false)
      @retry_non_idempotent_writes = env_flag("DHAN_RETRY_WRITES", default: false)
      @auto_correlation_id = env_flag("DHAN_AUTO_CORRELATION_ID", default: false)
      @warn_on_ambiguous_write_failure = env_flag("DHAN_WARN_AMBIGUOUS_WRITE_FAILURE", default: true)
      @base_url       = ENV.fetch("DHAN_BASE_URL", nil)
      @ws_version     = ENV.fetch("DHAN_WS_VERSION", 2).to_i
      @ws_order_url = ENV.fetch("DHAN_WS_ORDER_URL", nil)
      @ws_market_feed_url = ENV.fetch("DHAN_WS_MARKET_FEED_URL", nil)
      @ws_market_depth_url = ENV.fetch("DHAN_WS_MARKET_DEPTH_URL", nil)
      @market_depth_level = ENV.fetch("DHAN_MARKET_DEPTH_LEVEL", "20").to_i
      @ws_debug       = env_flag("DHAN_WS_DEBUG", default: false)
      @ws_user_type   = ENV.fetch("DHAN_WS_USER_TYPE", "SELF")
      @partner_id     = ENV.fetch("DHAN_PARTNER_ID", nil)
      @partner_secret = ENV.fetch("DHAN_PARTNER_SECRET", nil)
    end

    private

    # Reads a boolean-ish environment variable, falling back to +default+ when unset.
    def env_flag(name, default:)
      raw = ENV.fetch(name, nil)
      return default if raw.nil? || raw.to_s.strip.empty?

      raw.to_s.casecmp("true").zero?
    end
  end
end
