# frozen_string_literal: true

class MarketFeedLTP < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/marketfeed/ltp"

  def fetch(params)
    post("", params: params)
  end
end
