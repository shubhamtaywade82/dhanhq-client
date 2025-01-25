# frozen_string_literal: true

class MarginCalculator < DhanHQ::BaseAPI
  HTTP_PATH = "/v2/margincalculator"

  def calculate(params)
    post("", params: params)
  end
end
