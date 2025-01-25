# frozen_string_literal: true

class OptionChainExpiryList < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/optionchain/expirylist"

  def fetch(params)
    post("", params: params)
  end
end
