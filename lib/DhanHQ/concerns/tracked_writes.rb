# frozen_string_literal: true

require_relative "../write_result"

module DhanHQ
  module Concerns
    # Observes non-bang write methods and reports, once per call site, when one returns
    # a failure shape that 4.0.0 will change.
    #
    # Uses +prepend+ rather than +include+ because these methods are defined directly on
    # the model classes: an included module sits behind the class in the ancestor chain
    # and would never be reached. A prepended one sits in front, so +super+ runs the real
    # method and the result passes through untouched.
    #
    # This layer only observes. It never changes a return value, never raises, and goes
    # quiet once a call site has been migrated to the bang variant.
    #
    # @example
    #   class Order < BaseModel
    #     extend DhanHQ::Concerns::TrackedWrites
    #
    #     track_class_writes :place        # warns when Order.place returns nil
    #     track_writes :modify, :cancel    # warns when #cancel returns false
    #   end
    module TrackedWrites
      # Observes `<name>` instance methods.
      #
      # @param names [Array<Symbol>] Existing instance write methods to observe.
      # @return [void]
      def track_writes(*names)
        names.each { |name| prepend tracking_module(name) }
      end

      # Observes `<name>` class methods.
      #
      # @param names [Array<Symbol>] Existing class write methods to observe.
      # @return [void]
      def track_class_writes(*names)
        names.each { |name| singleton_class.prepend tracking_module(name) }
      end

      private

      def tracking_module(name)
        Module.new do
          define_method(name) do |*args, **kwargs, &block|
            DhanHQ::WriteResult.report_ambiguous_failure(
              super(*args, **kwargs, &block),
              operation: DhanHQ::WriteResult.operation_label(self, name)
            )
          end
        end
      end
    end
  end
end
