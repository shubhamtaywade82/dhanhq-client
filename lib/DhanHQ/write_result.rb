# frozen_string_literal: true

module DhanHQ
  # Interprets the several shapes a write currently uses to signal failure.
  #
  # The model write methods do not share a return contract. Depending on which class
  # and which failure you hit, a rejected write comes back as +nil+, as +false+, or as
  # a {DhanHQ::ErrorObject} — and {DhanHQ::Models::AlertOrder.modify} can return either
  # of the first two from the same method. A caller cannot write one error branch.
  #
  # Unifying those contracts is a breaking change for the applications that depend on
  # this gem, so it is staged (see CHANGELOG). This module is step one: it puts the
  # knowledge of "what does failure look like" in exactly one place, and backs the bang
  # variants (+place!+, +modify!+, +cancel!+, …) that give callers a single, explicit
  # failure mode to rescue today.
  #
  # @example Opting a call site into explicit failures
  #   order = DhanHQ::Models::Order.place!(params)   # raises DhanHQ::OrderError
  #   # instead of
  #   order = DhanHQ::Models::Order.place(params)    # nil on failure
  module WriteResult
    module_function

    # Whether a write result represents a rejected or failed operation.
    #
    # @param result [Object] Return value of a write method.
    # @return [Boolean]
    def failure?(result)
      result.nil? || result == false || result.is_a?(DhanHQ::ErrorObject)
    end

    # @param result [Object] Return value of a write method.
    # @return [Boolean]
    def success?(result)
      !failure?(result)
    end

    # Returns the result, or raises carrying whatever diagnostics the failure held.
    #
    # @param result [Object] Return value of a write method.
    # @param operation [String] Human-readable operation name for the message,
    #   e.g. +"DhanHQ::Models::Order.place"+.
    # @param error_class [Class] Exception to raise. Defaults to {DhanHQ::OrderError},
    #   which descends from {DhanHQ::Error}, so existing `rescue DhanHQ::Error`
    #   handlers still catch it.
    # @param errors [Hash, nil] Validation errors to report when the result itself
    #   carries none — typically a model's +errors+ hash.
    # @return [Object] The result, when it represents success.
    # @raise [DhanHQ::Error] When the result represents failure.
    def unwrap!(result, operation:, error_class: DhanHQ::OrderError, errors: nil)
      return result if success?(result)

      raise error_class, "#{operation} failed: #{describe(result, errors)}"
    end

    # Label identifying the operation that failed, for the exception message.
    #
    # @param receiver [Object] The class (for a class method) or instance.
    # @param name [Symbol] Method name.
    # @return [String] e.g. +"DhanHQ::Models::Order.place"+ or +"…Order#modify"+.
    def operation_label(receiver, name)
      return "#{module_label(receiver)}.#{name}" if receiver.is_a?(Module)

      "#{module_label(receiver.class)}##{name}"
    end

    # Reads a module's declared name, falling back to +to_s+ so an anonymous class
    # still yields something readable rather than an object address.
    #
    # @return [String]
    def module_label(mod)
      mod.name || mod.to_s
    end

    # Validation errors carried by a model instance, when it has any.
    #
    # @param receiver [Object]
    # @return [Hash, nil]
    def errors_from(receiver)
      return nil if receiver.is_a?(Module)
      return nil unless receiver.respond_to?(:errors)

      receiver.errors
    end

    # Best available explanation for a failure.
    #
    # @return [String]
    def describe(result, errors = nil)
      return result.errors.to_s if result.is_a?(DhanHQ::ErrorObject)
      return errors.to_s if errors && !errors.empty?

      # `nil` and `false` carry nothing, so say which of the two it was rather than
      # inventing a cause.
      result.nil? ? "the API returned no record" : "the API rejected the request"
    end
  end
end
