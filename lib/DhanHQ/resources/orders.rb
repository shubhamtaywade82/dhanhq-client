# frozen_string_literal: true

module DhanHQ
  module Resources
    # Handles order placement, modification, and cancellation
    class Orders < BaseAPI
      API_TYPE = :order_api
      HTTP_PATH = "/v2/orders"

      # --------------------------------------------------
      # PUBLIC API
      # --------------------------------------------------

      def create(params)
        security_id = params[:security_id] || params["securityId"] || params[:securityId]
        instrument_meta = instrument_meta_for!(security_id)
        validate_place_order!(params, instrument_meta)

        post("", params: params)
      end

      def update(order_id, params)
        security_id = params[:security_id] || params["securityId"] || params[:securityId] || fetch_security_id_for_order!(order_id)

        instrument_meta = instrument_meta_for!(security_id)
        validate_modify_order!(params.merge(order_id: order_id), instrument_meta)

        put("/#{order_id}", params: params)
      end

      def slicing(params)
        security_id = params[:security_id] || params["securityId"] || params[:securityId]
        instrument_meta = instrument_meta_for!(security_id)
        validate_place_order!(params, instrument_meta)

        post("/slicing", params: params)
      end

      def cancel(order_id)
        delete("/#{order_id}")
      end

      def all
        get("")
      end

      def find(order_id)
        get("/#{order_id}")
      end

      def by_correlation(correlation_id)
        get("/external/#{correlation_id}")
      end

      # --------------------------------------------------
      # VALIDATION LAYER
      # --------------------------------------------------

      private

      def validate_place_order!(params, instrument_meta)
        normalized = normalize_keys_for_validation(params)
        contract = Contracts::PlaceOrderContract.new(instrument_meta: instrument_meta)
        result = contract.call(normalized)

        raise_validation_error!(result) unless result.success?
      end

      def validate_modify_order!(params, instrument_meta)
        normalized = normalize_keys_for_validation(params)
        contract = Contracts::ModifyOrderContract.new(instrument_meta: instrument_meta)
        result = contract.call(normalized)

        raise_validation_error!(result) unless result.success?
      end

      def normalize_keys_for_validation(params)
        params.each_with_object({}) do |(k, v), memo|
          snake_key = k.to_s.gsub("::", "/")
                       .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
                       .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                       .tr("-", "_")
                       .downcase.to_sym
          memo[snake_key] = v
        end
      end

      def raise_validation_error!(result)
        raise DhanHQ::Error, "Validation Error: #{result.errors.to_h}"
      end

      # --------------------------------------------------
      # INSTRUMENT LOOKUP (CRITICAL SAFETY)
      # --------------------------------------------------

      def instrument_meta_for!(security_id)
        raise DhanHQ::Error, "security_id is required" unless security_id

        instrument = fetch_instrument!(security_id)

        {
          lot_size: instrument[:lot_size] || instrument["lotSize"],
          tick_size: instrument[:tick_size] || instrument["tickSize"],
          segment: instrument[:exchange_segment] || instrument["exchangeSegment"]
        }
      end

      def fetch_instrument!(security_id)
        # Prefer cached instrument service if available
        instrument = nil
        begin
          client = DhanHQ::Client.new
          instrument = client.instruments.find(security_id) if client.respond_to?(:instruments) && client.instruments.respond_to?(:find)
        rescue StandardError => e
          DhanHQ.logger&.error("Failed to fetch instrument: #{e.message}")
        end

        raise DhanHQ::Error, "Instrument not found for security_id=#{security_id}" unless instrument

        instrument
      end

      # --------------------------------------------------
      # MODIFY FALLBACK (Optional but Safe)
      # --------------------------------------------------

      def fetch_security_id_for_order!(order_id)
        order = find(order_id)

        security_id = order[:security_id] || order["securityId"]

        raise DhanHQ::Error, "Unable to determine security_id for order #{order_id}" unless security_id

        security_id
      end
    end
  end
end
