# frozen_string_literal: true

require "dotenv/load"

# Helper Methods
require_relative "DhanHQ/helpers/api_helper"
require_relative "DhanHQ/helpers/attribute_helper"
require_relative "DhanHQ/helpers/validation_helper"
require_relative "DhanHQ/helpers/request_helper"
require_relative "DhanHQ/helpers/response_helper"
require_relative "DhanHQ/json_loader"

require_relative "DhanHQ/core/base_api"
require_relative "DhanHQ/core/base_resource"
require_relative "DhanHQ/core/base_model"
require_relative "DhanHQ/core/error_handler"

require_relative "DhanHQ/version"
require_relative "DhanHQ/errors"
require_relative "DhanHQ/error_object"

require_relative "DhanHQ/client"
require_relative "DhanHQ/configuration"
require_relative "DhanHQ/rate_limiter"

# Contracts
require_relative "DhanHQ/contracts/base_contract"
require_relative "DhanHQ/contracts/historical_data_contract"

# Resources
require_relative "DhanHQ/resources/option_chain"
require_relative "DhanHQ/resources/orders"
require_relative "DhanHQ/resources/funds"
require_relative "DhanHQ/resources/holdings"
require_relative "DhanHQ/resources/positions"
require_relative "DhanHQ/resources/statements"
require_relative "DhanHQ/resources/historical_data"
require_relative "DhanHQ/resources/margin_calculator"
require_relative "DhanHQ/resources/market_feed"

# Models
require_relative "DhanHQ/models/order"
require_relative "DhanHQ/models/funds"
require_relative "DhanHQ/models/option_chain"
require_relative "DhanHQ/models/forever_order"
require_relative "DhanHQ/models/historical_data"
require_relative "DhanHQ/models/market_feed"
require_relative "DhanHQ/models/position"
require_relative "DhanHQ/models/holding"
require_relative "DhanHQ/models/ledger_entry"
require_relative "DhanHQ/models/trade"
require_relative "DhanHQ/models/margin"

require_relative "DhanHQ/constants"

# The top-level module for the DhanHQ client library.
#
# Provides configuration management for setting credentials and API-related settings.
module DhanHQ
  class Error < StandardError; end

  class << self
    BASE_URL = "https://api.dhan.co/v2"
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
      configuration.base_url = BASE_URL
    end
  end
end
