# frozen_string_literal: true

require_relative "../write_result"

module DhanHQ
  module Concerns
    # Generates bang variants of write methods that raise instead of returning a falsy
    # value or an {DhanHQ::ErrorObject}.
    #
    # Each generated method calls its non-bang counterpart and passes the result through
    # {DhanHQ::WriteResult.unwrap!}, so the two cannot drift: there is no duplicated
    # request building, validation or logging. The non-bang methods are untouched, which
    # is what makes this additive — existing callers keep the return values they were
    # written against.
    #
    # @example
    #   class Order < BaseModel
    #     extend DhanHQ::Concerns::BangWrites
    #
    #     bang_class_writes :place        # defines Order.place!
    #     bang_writes :modify, :cancel    # defines #modify! and #cancel!
    #   end
    #
    #   Order.place!(params)   # => Order, or raises DhanHQ::OrderError
    #   order.cancel!          # => true,  or raises DhanHQ::OrderError
    module BangWrites
      # Defines `<name>!` instance methods.
      #
      # @param names [Array<Symbol>] Existing instance write methods to wrap.
      # @param error_class [Class] Exception the generated methods raise.
      # @return [void]
      def bang_writes(*names, error_class: DhanHQ::OrderError)
        names.each { |name| include bang_write_module(name, error_class) }
      end

      # Defines `<name>!` class methods.
      #
      # @param names [Array<Symbol>] Existing class write methods to wrap.
      # @param error_class [Class] Exception the generated methods raise.
      # @return [void]
      def bang_class_writes(*names, error_class: DhanHQ::OrderError)
        names.each { |name| singleton_class.include bang_write_module(name, error_class) }
      end

      private

      # Built as a module rather than defined directly, so a hand-written `place!` in
      # the class body still overrides the generated one and can call `super`.
      def bang_write_module(name, error_class)
        Module.new do
          define_method(:"#{name}!") do |*args, **kwargs, &block|
            result = public_send(name, *args, **kwargs, &block)

            DhanHQ::WriteResult.unwrap!(
              result,
              operation: DhanHQ::WriteResult.operation_label(self, name),
              error_class: error_class,
              errors: DhanHQ::WriteResult.errors_from(self)
            )
          end
        end
      end
    end
  end
end
