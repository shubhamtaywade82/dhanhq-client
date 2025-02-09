# frozen_string_literal: true

module DhanHQ
  # The `Configuration` class manages API credentials and settings.
  #
  # Use this class to set the required `access_token` and `client_id`, as well as optional
  # settings such as the base URL and CSV URLs.
  #
  # @see https://dhanhq.co/docs/v2/ DhanHQ API Documentation
  class Configuration
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

    # Initializes a new configuration instance with default values.
    #
    # @example
    #   config = DhanHQ::Configuration.new
    #   config.client_id = "your_client_id"
    #   config.access_token = "your_access_token"
    def initialize
      @client_id = ENV.fetch("CLIENT_ID", nil)
      @access_token = ENV.fetch("ACCESS_TOKEN", nil)
      @base_url = BASE_URL
    end
  end
end
