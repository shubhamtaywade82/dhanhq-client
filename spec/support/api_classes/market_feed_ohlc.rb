# frozen_string_literal: true

class MarketFeedOHLC < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/marketfeed/ohlc"

  def fetch(params)
    post("", params: params)
  end
end
