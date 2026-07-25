# frozen_string_literal: true

module DhanHQ
  module Models
    ##
    # A basket of up to 15 orders placed in a single request via
    # POST /v2/alerts/multi/orders.
    #
    # Unlike {AlertOrder} there is no trigger condition — every leg goes to the
    # exchange immediately. The API answers with one result per leg, keyed by the
    # +sequence+ you supplied, so partial acceptance is visible.
    #
    # @example Place a two-leg basket
    #   result = DhanHQ::Models::MultiOrder.place([
    #     { sequence: "1", transaction_type: "BUY", exchange_segment: "NSE_EQ",
    #       product_type: "CNC", order_type: "LIMIT", validity: "DAY",
    #       security_id: "11536", quantity: 1, price: 1500.0 },
    #     { sequence: "2", transaction_type: "BUY", exchange_segment: "NSE_EQ",
    #       product_type: "CNC", order_type: "MARKET", validity: "DAY",
    #       security_id: "1333", quantity: 2 }
    #   ])
    #
    #   result.all_accepted?          # => true
    #   result.rejected               # => []
    #   result.order_ids              # => ["112111182198", "112111182199"]
    #   result.for_sequence("1").order_id
    #
    class MultiOrder < BaseModel
      extend DhanHQ::Concerns::BangWrites

      bang_class_writes :place

      HTTP_PATH = "/v2/alerts/multi/orders"

      attributes :orders

      ##
      # One leg's result within a {MultiOrder} response.
      class Leg < BaseModel
        attributes :order_id, :sequence, :order_status

        # @return [Boolean] True when the exchange accepted this leg.
        def accepted?
          !order_id.nil? && !rejected?
        end

        # @return [Boolean] True when this leg was rejected.
        def rejected?
          order_status.to_s == DhanHQ::Constants::OrderStatus::REJECTED
        end

        # Returns a concise prompt-friendly summary of the leg.
        def to_prompt
          "seq=#{sequence} order_id=#{order_id} status=#{order_status}"
        end
      end

      # Per-leg results.
      #
      # @return [Array<Leg>]
      def legs
        @legs ||= Array(orders).map { |leg| Leg.new(leg, skip_validation: true) }
      end

      # Order ids of every leg the API returned one for.
      #
      # @return [Array<String>]
      def order_ids
        legs.filter_map(&:order_id)
      end

      # Legs the exchange accepted.
      #
      # @return [Array<Leg>]
      def accepted
        legs.select(&:accepted?)
      end

      # Legs the exchange rejected.
      #
      # @return [Array<Leg>]
      def rejected
        legs.reject(&:accepted?)
      end

      # @return [Boolean] True when every leg was accepted.
      def all_accepted?
        legs.any? && rejected.empty?
      end

      # @return [Boolean] True when some but not all legs were accepted.
      def partially_accepted?
        accepted.any? && rejected.any?
      end

      # Looks up a leg by the sequence supplied at placement.
      #
      # @param sequence [String, Integer]
      # @return [Leg, nil]
      def for_sequence(sequence)
        legs.find { |leg| leg.sequence.to_s == sequence.to_s }
      end

      # Returns a concise prompt-friendly summary of the basket.
      def to_prompt
        "#{legs.size} legs, #{accepted.size} accepted, #{rejected.size} rejected"
      end

      class << self
        # @return [DhanHQ::Resources::MultiOrders]
        def resource
          @resource ||= DhanHQ::Resources::MultiOrders.new
        end

        # Places a basket of orders.
        #
        # @param orders [Array<Hash>] Order legs. See {DhanHQ::Contracts::MultiOrderContract}.
        # @param dhan_client_id [String, nil] Defaults to the configured client id.
        # @return [MultiOrder, DhanHQ::ErrorObject]
        def place(orders, dhan_client_id: nil)
          DhanHQ.logger&.info("[#{name}] Placing multi order with #{Array(orders).size} legs")
          response = resource.create(orders, dhan_client_id: dhan_client_id)

          # The API may answer with a bare array of leg results or wrap it in `orders`.
          payload = response.is_a?(Array) ? { orders: response } : response
          return DhanHQ::ErrorObject.new(response) unless payload.is_a?(Hash) && payload[:orders]

          new(payload, skip_validation: true)
        end
        alias create place
      end
    end
  end
end
