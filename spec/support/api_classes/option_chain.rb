# frozen_string_literal: true

class OptionChain < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/optionchain"

  def fetch(params)
    post("", params: params)
  end
end
