# frozen_string_literal: true

module DhanHQ
  class BaseResource < BaseAPI
    def initialize(api_type: :order_api)
      super(api_type: api_type) # rubocop:disable Style/SuperArguments
    end

    def all
      get(self.class::HTTP_PATH)
    end

    def find(id)
      get("#{self.class::HTTP_PATH}/#{id}")
    end

    def create(params)
      post(self.class::HTTP_PATH, params: params)
    end

    def update(id, params)
      put("#{self.class::HTTP_PATH}/#{id}", params: params)
    end

    def delete(id)
      super("#{self.class::HTTP_PATH}/#{id}")
    end
  end
end
