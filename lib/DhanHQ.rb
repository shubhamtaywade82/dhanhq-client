# frozen_string_literal: true

require_relative "DhanHQ/version"

require_relative "DhanHQ/configuration"
require_relative "DhanHQ/client"
require_relative "DhanHQ/base_resource"
require_relative "DhanHQ/base_api"

require_relative "DhanHQ/resources/orders"

require_relative "DhanHQ/models/order"

require_relative "DhanHQ/error_handler"

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
  end
end
