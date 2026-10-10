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

    # All environments a client can run in.
    #
    # - +:live+ — every request hits the production host.
    # - +:sandbox+ — every request hits the sandbox host (previous `sandbox = true` behaviour).
    # - +:hybrid+ — market data (quotes, option chain, charts, instruments, ScanX)
    #   hits production while trading/account requests hit the sandbox host, so a
    #   strategy rehearses execution against real prices without risking money.
    # @return [Array<Symbol>]
    MODES = %i[live sandbox hybrid].freeze

    # API tiers routed to the production host when {#mode} is +:hybrid+.
    # Everything else (orders, positions, funds, statements, ...) routes to the
    # sandbox host. Global Stocks keeps its own tier so it stays on production in
    # hybrid mode — the sandbox host does not mirror the US-equities API.
    # @return [Array<Symbol>]
    HYBRID_LIVE_API_TYPES = %i[data_api quote_api option_chain global_stocks_api].freeze

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
    #
    # Backward-compatible facade over {#mode}: setting it to +true+ switches to
    # full sandbox mode, +false+ back to live. Prefer {#mode} for new code — it
    # also supports +:hybrid+ (live market data + sandbox execution).
    #
    # rubocop:disable Naming/PredicateMethod -- legacy attr_accessor-style API,
    # kept as a boolean mirror of +mode+ for every caller written before :hybrid.
    # @return [Boolean] True when every request targets the sandbox host.
    def sandbox
      mode == :sandbox
    end
    # rubocop:enable Naming/PredicateMethod

    def sandbox=(value)
      self.mode = value ? :sandbox : :live
    end

    # The environment the client runs in: +:live+, +:sandbox+, or +:hybrid+.
    #
    # Set via +DHAN_MODE+ or in {DhanHQ.configure}. {#sandbox=} remains as an
    # alias for switching between +:live+ and +:sandbox+.
    #
    # @return [Symbol]
    attr_reader :mode

    # @param value [Symbol, String] One of {MODES} (case-insensitive).
    # @raise [ArgumentError] When the value is not a known mode.
    def mode=(value)
      @mode = coerce_mode!(value)
    end

    # Per-tier environment overrides applied on top of {#mode}.
    #
    # Keys are API tier symbols (+:order_api+, +:data_api+, +:quote_api+,
    # +:option_chain+, +:non_trading_api+, +:global_stocks_api+); values are
    # +:live+ or +:sandbox+. Useful to, say, keep fund limits on production while
    # everything else runs on the sandbox in hybrid mode:
    #
    #   DhanHQ.configure do |c|
    #     c.mode = :hybrid
    #     c.environment_overrides = { non_trading_api: :live }
    #   end
    #
    # @return [Hash{Symbol => Symbol}]
    attr_reader :environment_overrides

    def environment_overrides=(value)
      @environment_overrides = coerce_environment_overrides(value)
    end

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

    # Contract-first request validation: when +true+, every request whose
    # operation has a request schema in the vendored OpenAPI contract is
    # structurally validated (required fields, types, enums, bounds) before it
    # leaves the process, and violations raise {DhanHQ::ValidationError} the
    # same way the dry-validation contracts do. The vendor spec is patched by
    # the overlays in contracts/overlays/ (see overlay 0005 for the enum
    # reconciliation), so validated enums match the documented reality.
    #
    # Defaults to +true+: a payload the contract rejects is a bug this side of
    # the wire, and failing locally is strictly better than a DH-905 round trip.
    # Set to +false+ to skip (e.g. while migrating a large app), or via
    # +DHAN_VALIDATE_REQUESTS=false+.
    # @return [Boolean]
    attr_accessor :validate_requests

    # Contract-first response validation: when +true+, parsed 2xx responses are
    # checked against the operation's response schema and mismatches are logged
    # (never raised) — an early-warning system for upstream drift such as the
    # casing inconsistencies documented in REVIEW.md. Defaults to +false+;
    # enable via +DHAN_VALIDATE_RESPONSES=true+ or in {DhanHQ.configure}.
    # @return [Boolean]
    attr_accessor :validate_responses

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
      base_url_for(nil)
    end

    # Returns the base URL for requests on the given API tier, honouring
    # {#mode}, {#environment_overrides}, and an explicit {#base_url} override.
    #
    # In +:hybrid+ mode data tiers (see {HYBRID_LIVE_API_TYPES}) resolve to the
    # production host while trading and account tiers resolve to the sandbox
    # host, which is what lets a strategy read live prices while placing paper
    # orders.
    #
    # @param api_type [Symbol, nil] API tier the request belongs to. +nil+ uses
    #   the mode-level default (+:sandbox+ mode resolves to the sandbox host,
    #   +:live+ and +:hybrid+ to production).
    # @return [String]
    def base_url_for(api_type)
      if environment_for(api_type) == :sandbox && (@base_url.nil? || @base_url == BASE_URL)
        SANDBOX_URL
      else
        @base_url || BASE_URL
      end
    end

    # The effective environment (+:live+ or +:sandbox+) for requests on the
    # given API tier. Explicit {#environment_overrides} win over the {#mode}
    # defaults.
    #
    # @param api_type [Symbol, nil]
    # @return [Symbol]
    def environment_for(api_type)
      key = api_type&.to_sym
      return @environment_overrides[key] if key && @environment_overrides.key?(key)

      case mode
      when :sandbox then :sandbox
      when :hybrid then HYBRID_LIVE_API_TYPES.include?(key) ? :live : :sandbox
      else :live
      end
    end

    def sandbox?
      mode == :sandbox
    end

    # True when {#mode} is +:hybrid+ — live market data, sandbox execution.
    # @return [Boolean]
    def hybrid?
      mode == :hybrid
    end

    # @return [Boolean] True when state-changing requests should be simulated.
    def dry_run?
      @dry_run == true
    end

    # @return [Boolean] True when wire payloads are structurally validated
    #   against the vendored contract before being sent.
    def validate_requests?
      @validate_requests != false
    end

    # @return [Boolean] True when 2xx responses are checked against the
    #   contract (logged drift, never raised).
    def validate_responses?
      @validate_responses == true
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

    def initialize(attrs = {})
      @client_id = attrs[:client_id] || ENV.fetch("DHAN_CLIENT_ID", nil)
      @access_token = attrs[:access_token] || ENV.fetch("DHAN_ACCESS_TOKEN", nil)
      @access_token_provider = attrs[:access_token_provider]
      @on_token_expired = attrs[:on_token_expired]
      @sandbox = attrs.key?(:sandbox) ? attrs[:sandbox] : env_flag("DHAN_SANDBOX", default: false)
      @dry_run = attrs.key?(:dry_run) ? attrs[:dry_run] : env_flag("DHAN_DRY_RUN", default: false)
      @retry_non_idempotent_writes = attrs.key?(:retry_non_idempotent_writes) ? attrs[:retry_non_idempotent_writes] : env_flag("DHAN_RETRY_WRITES", default: false)
      @auto_correlation_id = attrs.key?(:auto_correlation_id) ? attrs[:auto_correlation_id] : env_flag("DHAN_AUTO_CORRELATION_ID", default: false)
      @validate_requests = attrs.key?(:validate_requests) ? attrs[:validate_requests] : env_flag("DHAN_VALIDATE_REQUESTS", default: true)
      @validate_responses = attrs.key?(:validate_responses) ? attrs[:validate_responses] : env_flag("DHAN_VALIDATE_RESPONSES", default: false)
      @warn_on_ambiguous_write_failure = if attrs.key?(:warn_on_ambiguous_write_failure)
                                           attrs[:warn_on_ambiguous_write_failure]
                                         else
                                           env_flag("DHAN_WARN_AMBIGUOUS_WRITE_FAILURE",
                                                    default: true)
                                         end
      @base_url = attrs[:base_url] || ENV.fetch("DHAN_BASE_URL", nil)
      @environment_overrides = coerce_environment_overrides(
        attrs[:environment_overrides] || ENV.fetch("DHAN_ENV_OVERRIDES", nil)
      )
      @mode = resolve_mode(attrs)
      @ws_version = (attrs[:ws_version] || ENV.fetch("DHAN_WS_VERSION", 2)).to_i
      @ws_order_url = attrs[:ws_order_url] || ENV.fetch("DHAN_WS_ORDER_URL", nil)
      @ws_market_feed_url = attrs[:ws_market_feed_url] || ENV.fetch("DHAN_WS_MARKET_FEED_URL", nil)
      @ws_market_depth_url = attrs[:ws_market_depth_url] || ENV.fetch("DHAN_WS_MARKET_DEPTH_URL", nil)
      @market_depth_level = (attrs[:market_depth_level] || ENV.fetch("DHAN_MARKET_DEPTH_LEVEL", "20")).to_i
      @ws_debug = attrs.key?(:ws_debug) ? attrs[:ws_debug] : env_flag("DHAN_WS_DEBUG", default: false)
      @ws_user_type = attrs[:ws_user_type] || ENV.fetch("DHAN_WS_USER_TYPE", "SELF")
      @partner_id = attrs[:partner_id] || ENV.fetch("DHAN_PARTNER_ID", nil)
      @partner_secret = attrs[:partner_secret] || ENV.fetch("DHAN_PARTNER_SECRET", nil)
      yield(self) if block_given?
    end

    private

    # Resolves the initial mode from attributes and ENV.
    #
    # Precedence: an explicit +:mode+ attribute wins, then +DHAN_MODE+, then the
    # legacy +sandbox+ attribute / +DHAN_SANDBOX+ flag, then +:live+.
    def resolve_mode(attrs)
      raw_mode = attrs.key?(:mode) ? attrs[:mode] : ENV.fetch("DHAN_MODE", nil)
      return coerce_mode!(raw_mode) if raw_mode

      sandbox_flag = attrs.key?(:sandbox) ? attrs[:sandbox] : env_flag("DHAN_SANDBOX", default: false)
      sandbox_flag ? :sandbox : :live
    end

    # Normalises a mode value, raising on anything outside {MODES}.
    def coerce_mode!(value)
      mode = value.to_s.strip.downcase.to_sym
      raise ArgumentError, "unknown mode #{value.inspect}: expected one of #{MODES.join(", ")}" unless MODES.include?(mode)

      mode
    end

    # Valid targets for an environment override.
    OVERRIDE_TARGETS = %i[live sandbox].freeze
    private_constant :OVERRIDE_TARGETS

    # Normalises an environment-overrides hash: symbol keys, :live/:sandbox values.
    def coerce_environment_overrides(value)
      return {} if value.nil? || value == ""

      value = value.split(",").to_h { |pair| pair.split("=") } if value.is_a?(String)
      raise ArgumentError, "environment_overrides must be a Hash (tier => :live/:sandbox)" unless value.is_a?(Hash)

      value.each_with_object({}) do |(tier, env), out|
        key = tier.to_s.strip.to_sym
        target = env.to_s.strip.downcase.to_sym
        raise ArgumentError, "environment override for #{key} must be :live or :sandbox (got #{env.inspect})" unless OVERRIDE_TARGETS.include?(target)

        out[key] = target
      end
    end

    # Reads a boolean-ish environment variable, falling back to +default+ when unset.
    def env_flag(name, default:)
      raw = ENV.fetch(name, nil)
      return default if raw.nil? || raw.to_s.strip.empty?

      raw.to_s.casecmp("true").zero?
    end
  end
end
