# frozen_string_literal: true

module DhanHQ
  module Resources
    # Resource for alert/conditional orders per API docs: /alerts/orders (GET/POST/PUT/DELETE).
    class AlertOrders < BaseResource
      API_TYPE  = :order_api
      HTTP_PATH = "/alerts/orders"
    end
  end
end
