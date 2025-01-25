# frozen_string_literal: true

class ChartsHistorical < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/charts/historical"

  def fetch(params)
    post("", params: params)
  end
end
