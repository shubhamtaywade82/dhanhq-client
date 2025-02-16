# frozen_string_literal: true

require "dotenv/load"

# Helper Methods
require_relative "DhanHQ/helpers/api_helper"
require_relative "DhanHQ/helpers/attribute_helper"
require_relative "DhanHQ/helpers/validation_helper"
require_relative "DhanHQ/helpers/request_helper"
require_relative "DhanHQ/helpers/response_helper"

require_relative "DhanHQ/version"
require_relative "DhanHQ/errors"

require_relative "DhanHQ/client"
require_relative "DhanHQ/configuration"
require_relative "DhanHQ/rate_limiter"
require_relative "DhanHQ/base_api"
require_relative "DhanHQ/base_model"

# Contracts
require_relative "DhanHQ/contracts/base_contract"

# Models
require_relative "DhanHQ/models/order"
require_relative "DhanHQ/models/funds"
require_relative "DhanHQ/models/option_chain"
require_relative "DhanHQ/models/forever_order"
require_relative "DhanHQ/models/historical_data"
require_relative "DhanHQ/models/market_feed"
require_relative "DhanHQ/models/portfolio"
require_relative "DhanHQ/models/trade"

require_relative "DhanHQ/error_handler"

require_relative "DhanHQ/constants"

# The top-level module for the DhanHQ client library.
#
# Provides configuration management for setting credentials and API-related settings.
module DhanHQ
  class Error < StandardError; end

  class << self
    # The current configuration instance.
    #
    # @return [DhanHQ::Configuration, nil] The current configuration or `nil` if not set.
    attr_accessor :configuration

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
    end

    # Configures the DhanHQ client with user-defined settings.
    #
    # @example
    #   DhanHQ.configure_with_env
    #
    # @return [void]
    def configure_with_env
      self.configuration ||= Configuration.new
      configuration.access_token = ENV.fetch("ACCESS_TOKEN", nil)
      configuration.client_id = ENV.fetch("CLIENT_ID", nil)
    end
  end
end
