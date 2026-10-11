# frozen_string_literal: true

module DhanHQ
  module Risk
    # Classifies an order against the account's open positions.
    #
    # A risk-reducing order — the opposite side of an open position in the same
    # instrument and product, for no more than that position's size — only shrinks
    # exposure. Limit checks (position count, daily loss, concentration, size caps,
    # ASM/GSM) must never block it: refusing a stop-out because the account is
    # already over a limit turns a capped loss into an uncapped one.
    module Exposure
      # @param args [Hash] Order arguments with snake_case String keys.
      # @param positions [Array<#security_id, #exchange_segment, #product_type, #net_qty>]
      # @return [Boolean] True when the order only reduces an existing position.
      def self.reducing?(args, positions)
        quantity = args["quantity"].to_i
        side = args["transaction_type"].to_s.upcase
        return false unless quantity.positive? && Constants::TransactionType::ALL.include?(side)

        position = matching_position(args, positions)
        return false unless position

        net = position.net_qty.to_i
        closes = side == Constants::TransactionType::SELL ? net.positive? : net.negative?
        closes && quantity <= net.abs
      end

      def self.matching_position(args, positions)
        security_id = args["security_id"].to_s
        return nil if security_id.empty?

        Array(positions).find do |position|
          position.net_qty.to_i != 0 &&
            position.security_id.to_s == security_id &&
            same_or_unspecified?(args["exchange_segment"], position.exchange_segment) &&
            same_or_unspecified?(args["product_type"], position.product_type)
        end
      end

      def self.same_or_unspecified?(wanted, actual)
        wanted.nil? || wanted.to_s.empty? || wanted.to_s == actual.to_s
      end

      private_class_method :matching_position, :same_or_unspecified?
    end
  end
end
