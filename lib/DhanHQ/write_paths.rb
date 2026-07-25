# frozen_string_literal: true

module DhanHQ
  # Classifies request paths by whether they change account state.
  #
  # The distinction that matters on this API is **mutating vs read-only**, not GET vs
  # POST: the option chain, market feed, historical charts and the margin calculators
  # are all read-only POSTs. Both dry-run simulation and non-idempotent retry gating
  # need that answer, so it lives here rather than in {DhanHQ::Client}.
  module WritePaths
    # HTTP methods that can change server-side state.
    WRITE_METHODS = %i[post put patch delete].freeze

    # Path of the basket order endpoint, which answers with one result per leg
    # rather than a single order id.
    MULTI_ORDER_PATH = "/v2/alerts/multi/orders"

    module_function

    # True when this request changes real account state.
    #
    # @param method [Symbol] HTTP method
    # @param path [String, nil] Request path
    # @return [Boolean]
    def mutating?(method, path)
      return false unless WRITE_METHODS.include?(method)

      match?(path, DhanHQ::Constants::MUTATING_PATH_PREFIXES)
    end

    # True when this request places one or more orders.
    #
    # @param method [Symbol] HTTP method
    # @param path [String, nil] Request path
    # @return [Boolean]
    def order_placement?(method, path)
      return false unless method == :post

      match?(path, DhanHQ::Constants::ORDER_PLACEMENT_PATH_PREFIXES)
    end

    # True for the basket order endpoint.
    #
    # @param path [String, nil] Request path
    # @return [Boolean]
    def multi_order?(path)
      path.to_s.start_with?(MULTI_ORDER_PATH)
    end

    def match?(path, prefixes)
      return false if path.nil?

      prefixes.any? { |prefix| path.start_with?(prefix) }
    end
    private_class_method :match?
  end
end
