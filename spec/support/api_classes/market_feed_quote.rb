# frozen_string_literal: true

class MarketFeedQuote < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/marketfeed/quote"

  def fetch(params)
    post("", params: params)
  end
end
