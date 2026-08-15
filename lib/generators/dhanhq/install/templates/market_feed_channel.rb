# frozen_string_literal: true

class DhanMarketFeedChannel < ApplicationCable::Channel
  def subscribed
    stream_from "dhan_market_feed"
  end
end
