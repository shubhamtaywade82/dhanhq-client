# frozen_string_literal: true

require_relative "../contracts/alert_order_contract"

module DhanHQ
  module Models
    # Model for alert/conditional orders. CRUD via AlertOrders resource; validated by AlertOrderContract.
    class AlertOrder < BaseModel
      include Concerns::ApiResponseHandler

      HTTP_PATH = "/alerts/orders"

      attributes :alert_id, :exchange_segment, :security_id, :condition,
                 :trigger_price, :order_type, :transaction_type, :quantity,
                 :price, :status, :created_at

      class << self
        def api_type
          :order_api
        end

        def resource
          @resource ||= DhanHQ::Resources::AlertOrders.new
        end

        def validation_contract
          Contracts::AlertOrderContract
        end

        def all
          response = resource.all
          parse_collection_response(response)
        end

        def find(alert_id)
          response = resource.find(alert_id)
          return nil unless response.is_a?(Hash) || (response.is_a?(Array) && response.any?)

          payload = response.is_a?(Array) ? response.first : response
          new(payload, skip_validation: true)
        end

        def create(params)
          normalized = snake_case(params)
          validate_params!(normalized, DhanHQ::Contracts::AlertOrderContract)
          response = resource.create(camelize_keys(normalized))
          return nil unless response.is_a?(Hash) && response["alertId"]

          find(response["alertId"])
        end

        ##
        # Modify an existing conditional trigger/alert order.
        #
        # @param alert_id [String] The alert ID to modify
        # @param params [Hash] Updated parameters (condition, orders, etc.)
        #
        # @return [AlertOrder, nil] Updated AlertOrder instance, or nil on failure
        #
        # @example Modify an alert order's condition
        #   updated = DhanHQ::Models::AlertOrder.modify("12345",
        #     condition: { comparing_value: 300 },
        #     orders: [{ quantity: 20 }]
        #   )
        #
        def modify(alert_id, params)
          normalized = snake_case(params)
          response = resource.update(alert_id, camelize_keys(normalized))
          return nil unless success_response?(response)

          find(alert_id)
        end
      end

      def id
        alert_id&.to_s
      end

      def save
        return false unless valid?

        payload = to_request_params
        response = if new_record?
                     self.class.resource.create(payload)
                   else
                     self.class.resource.update(id, payload)
                   end

        handle_api_response(response, success_key: new_record? ? "alertId" : nil)
      end

      def destroy # rubocop:disable Naming/PredicateMethod
        return false if new_record?

        response = self.class.resource.delete(id)
        success_response?(response)
      end
      alias delete destroy
    end
  end
end
