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
    #
    # @return [String]
    BASE_URL = "https://api.dhan.co/v2"
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
    # @return [String] The base URL for the DhanHQ API.
    attr_accessor :base_url

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
    # @return [String]
    attr_accessor :ws_order_url

    # Websocket market feed endpoint.
    # @return [String]
    attr_accessor :ws_market_feed_url

    # Websocket market depth endpoint.
    # @return [String]
    attr_accessor :ws_market_depth_url

    # Market depth level (20 or 200).
    # @return [Integer]
    attr_accessor :market_depth_level

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

    # Initializes a new configuration instance with default values.
    #
    # @example
    #   config = DhanHQ::Configuration.new
    #   config.client_id = "your_client_id"
    #   config.access_token = "your_access_token"
    def initialize
      @client_id = ENV.fetch("DHAN_CLIENT_ID", nil)
      @access_token = ENV.fetch("DHAN_ACCESS_TOKEN", nil)
      @base_url       = ENV.fetch("DHAN_BASE_URL", "https://api.dhan.co/v2")
      @ws_version     = ENV.fetch("DHAN_WS_VERSION", 2).to_i
      @ws_order_url = ENV.fetch("DHAN_WS_ORDER_URL", "wss://api-order-update.dhan.co")
      @ws_market_feed_url = ENV.fetch("DHAN_WS_MARKET_FEED_URL", "wss://api-feed.dhan.co")
      @ws_market_depth_url = ENV.fetch("DHAN_WS_MARKET_DEPTH_URL", "wss://depth-api-feed.dhan.co/twentydepth")
      @market_depth_level = ENV.fetch("DHAN_MARKET_DEPTH_LEVEL", "20").to_i
      @ws_user_type   = ENV.fetch("DHAN_WS_USER_TYPE", "SELF")
      @partner_id     = ENV.fetch("DHAN_PARTNER_ID", nil)
      @partner_secret = ENV.fetch("DHAN_PARTNER_SECRET", nil)
    end
  end
end
