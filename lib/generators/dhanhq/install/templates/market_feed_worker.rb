# frozen_string_literal: true

# Keeps a DhanHQ market feed connection open and broadcasts ticks over
# ActionCable. Start it with DhanMarketFeedWorker.perform_async -- the job
# blocks for the life of the connection rather than completing immediately,
# so Sidekiq's dashboard reflects whether the feed is actually running.
#
# retry: false because there is nothing to retry: the underlying
# DhanHQ::WS::Client already reconnects and re-subscribes on its own.
class DhanMarketFeedWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(mode = "quote")
    client = DhanHQ::WS.connect(mode: mode.to_sym) do |tick|
      ActionCable.server.broadcast("dhan_market_feed", tick)
    end

    client.on(:reconnect) { |info| Rails.logger.warn("[DhanMarketFeedWorker] reconnect ##{info[:attempt]}") }
    client.on(:error) { |message| Rails.logger.error("[DhanMarketFeedWorker] #{message}") }

    loop do
      sleep 30
      break unless client.connected?
    end
  end
end
