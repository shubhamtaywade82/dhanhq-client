# frozen_string_literal: true

require "rails/generators"

module Dhanhq
  # Scaffolds a DhanHQ initializer, a sample order-placing service object, and
  # a Sidekiq worker + ActionCable channel for streaming market data.
  #
  #   rails generate dhanhq:install
  #
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    def create_initializer
      template "initializer.rb", "config/initializers/dhanhq.rb"
    end

    def create_order_service
      template "place_order_service.rb", "app/services/dhan/orders/place_order.rb"
    end

    def create_market_feed_worker
      template "market_feed_worker.rb", "app/workers/dhan_market_feed_worker.rb"
    end

    def create_market_feed_channel
      template "market_feed_channel.rb", "app/channels/dhan_market_feed_channel.rb"
    end

    def show_post_install_message
      say ""
      say "DhanHQ installed! Next steps:", :green
      say "  1. Add your credentials:"
      say "       rails credentials:edit"
      say "       dhanhq:"
      say "         client_id: \"your_client_id\""
      say "         access_token: \"your_access_token\""
      say "  2. Set LIVE_TRADING=true before placing real orders (see docs/CONFIGURATION.md)"
      say "  3. Start the market feed: DhanMarketFeedWorker.perform_async"
      say ""
      say "Full reference: https://github.com/shubhamtaywade82/dhanhq-client/blob/main/docs/RAILS_INTEGRATION.md"
      say ""
    end
  end
end
