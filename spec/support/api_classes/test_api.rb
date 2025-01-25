# frozen_string_literal: true

module DhanHQ
  class TestAPI < BaseAPI
    HTTP_PATH = "/v2/test"

    def fetch(params)
      post("", params: params)
    end

    def update(id, params)
      put("/#{id}", params: params)
    end
  end
end
