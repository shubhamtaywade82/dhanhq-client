# frozen_string_literal: true

require_relative "../contracts/alert_order_contract"

module DhanHQ
  module Models
    # Model for alert/conditional orders. CRUD via AlertOrders resource; validated by AlertOrderContract.
    class AlertOrder < BaseModel
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
          return [] unless response.is_a?(Array)

          response.map { |attrs| new(attrs, skip_validation: true) }
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
      end

      def id
        alert_id&.to_s
      end

      def save # rubocop:disable Naming/PredicateMethod
        return false unless valid?

        payload = to_request_params
        response = if new_record?
                     self.class.resource.create(camelize_keys(payload))
                   else
                     self.class.resource.update(id, camelize_keys(payload))
                   end
        return false if new_record? && !(response.is_a?(Hash) && response["alertId"])
        return false if !new_record? && !success_response?(response)

        @attributes.merge!(normalize_keys(response))
        assign_attributes
        true
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
