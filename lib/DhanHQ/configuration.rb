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

    # Websocket user type for order updates.
    # @return [String] "SELF" or "PARTNER".
    attr_accessor :ws_user_type

    # Partner ID for order updates when `ws_user_type` is "PARTNER".
    # @return [String, nil]
    attr_accessor :partner_id

    # Partner secret for order updates when `ws_user_type` is "PARTNER".
    # @return [String, nil]
    attr_accessor :partner_secret

    # Initializes a new configuration instance with default values.
    #
    # @example
    #   config = DhanHQ::Configuration.new
    #   config.client_id = "your_client_id"
    #   config.access_token = "your_access_token"
    def initialize
      @client_id = ENV.fetch("CLIENT_ID", nil)
      @access_token = ENV.fetch("ACCESS_TOKEN", nil)
      @base_url       = ENV.fetch("DHAN_BASE_URL", "https://api.dhan.co/v2")
      @ws_version     = ENV.fetch("DHAN_WS_VERSION", 2).to_i
      @ws_order_url   = ENV.fetch("DHAN_WS_ORDER_URL", "wss://api-order-update.dhan.co")
      @ws_user_type   = ENV.fetch("DHAN_WS_USER_TYPE", "SELF")
      @partner_id     = ENV.fetch("DHAN_PARTNER_ID", nil)
      @partner_secret = ENV.fetch("DHAN_PARTNER_SECRET", nil)
    end
  end
end
