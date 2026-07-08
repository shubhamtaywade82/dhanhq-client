# frozen_string_literal: true

module DhanHQ
  module Skills
    # Workflow orchestrates multi-step skill execution with branching and error handling.
    #
    # A workflow is a sequence of steps that can succeed, fail, or branch
    # based on the result of each step.
    #
    # @example Define a workflow
    #   workflow = DhanHQ::Skills::Workflow.new do
    #     step :check_funds do |ctx|
    #       funds = DhanHQ::Models::Funds.fetch
    #       ctx[:available_balance] = funds[:available_balance]
    #       ctx
    #     end
    #
    #     step :validate_margin do |ctx|
    #       raise "Insufficient margin" if ctx[:available_balance] < 10_000
    #       ctx
    #     end
    #
    #     step :place_order do |ctx|
    #       ctx[:order] = DhanHQ::Models::Order.place(ctx[:order_params])
    #       ctx
    #     end
    #   end
    #
    #   result = workflow.call(order_params: { ... })
    #
    class Workflow
      Step = Struct.new(:name, :block, :priority)

      attr_reader :name, :steps

      def initialize(name: "workflow", &block)
        @name = name
        @steps = []
        instance_eval(&block) if block
      end

      # Define a step in the workflow.
      #
      # @param name [Symbol] step name
      # @param priority [Integer] execution order (lower = earlier)
      # @param block [Proc] step implementation
      def step(name, priority: 10, &block)
        @steps << Step.new(name, block, priority)
        @steps.sort_by!(&:priority)
      end

      # Execute the workflow with the given context.
      #
      # @param ctx [Hash] initial context
      # @return [Hash] final context after all steps
      # @raise [RuntimeError] if any step fails
      def call(ctx = {})
        @steps.each do |step|
          result = step.block.call(ctx)
          ctx = result if result.is_a?(Hash)
        end
        ctx
      end
    end
  end
end
