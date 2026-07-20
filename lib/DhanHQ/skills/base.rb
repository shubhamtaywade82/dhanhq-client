# frozen_string_literal: true

module DhanHQ
  module Skills
    # Base class for all trading skills.
    #
    # Provides a DSL for defining parameters, steps, and execution logic.
    # Skills are stateless — context is passed through and returned.
    #
    # @example
    #   class BuyAtmCall < DhanHQ::Skills::Base
    #     param :symbol, type: :string, required: true
    #     param :expiry, type: :string, required: true
    #     param :quantity, type: :integer, default: 50
    #
    #     step :find_instrument
    #     step :get_spot_price
    #     step :prepare_intent
    #
    #     def find_instrument(ctx)
    #       ctx[:instrument] = DhanHQ::Models::Instrument.find("IDX_I", ctx[:symbol])
    #       ctx
    #     end
    #
    #     def get_spot_price(ctx)
    #       ctx[:spot_price] = ctx[:instrument].ltp
    #       ctx
    #     end
    #
    #     def prepare_intent(ctx)
    #       ctx[:intent] = { symbol: ctx[:symbol], spot: ctx[:spot_price] }
    #       ctx
    #     end
    #   end
    #
    class Base
      class << self
        # Define a parameter for this skill.
        #
        # @param name [Symbol] parameter name
        # @param type [Symbol] :string, :integer, :number, :boolean
        # @param required [Boolean] whether the parameter is required
        # @param default [Object] default value if not provided
        def param(name, type: :string, required: false, default: nil, description: nil)
          @params ||= {}
          @params[name] = { type: type, required: required, default: default, description: description }
        end

        # Define a step in the skill execution sequence.
        #
        # @param name [Symbol] method name to call
        # @param priority [Integer] execution order (lower = earlier)
        def step(name, priority: 10)
          @steps ||= []
          @steps << { name: name, priority: priority }
          @steps.sort_by! { |s| s[:priority] }
        end

        # MCP risk level for this skill (defaults to the most conservative tier
        # so a skill that forgets to declare one fails safe/write-gated).
        #
        # @param level [String, nil] one of read_only, trade_adjacent_read, live_write, destructive_write
        def risk(level = nil)
          level ? (@risk = level) : (@risk || "destructive_write")
        end

        # MCP policy scope required to invoke this skill.
        #
        # @param value [String, nil] e.g. "orders:read", "orders:write"
        def scope(value = nil)
          value ? (@scope = value) : (@scope || "orders:write")
        end

        # Human-readable description shown to MCP/LLM clients in tools/list.
        #
        # @param text [String, nil] one-line summary of what the skill does
        def description(text = nil)
          text ? (@description = text) : @description
        end

        # Accessor for defined parameters.
        def params
          @params || {}
        end

        # Accessor for defined steps.
        def steps
          @steps || []
        end

        # Validate that all required parameters are present.
        #
        # @param args [Hash] provided parameters
        # @raise [ArgumentError] if required parameters are missing
        def validate_params!(args)
          params.each do |name, config|
            next unless config[:required]

            value = args[name] || args[name.to_s]
            next unless value.nil?

            raise ArgumentError, "Missing required parameter: #{name}"
          end
        end
      end

      # Execute the skill with the given arguments.
      #
      # @param args [Hash] skill parameters (symbol or string keys)
      # @return [Hash] context with all accumulated state
      # @raise [ArgumentError] if required parameters are missing
      def call(args = {})
        ctx = build_context(args)
        self.class.validate_params!(ctx)

        self.class.steps.each do |step|
          result = send(step[:name], ctx)
          ctx = result if result.is_a?(Hash)
        end

        ctx
      end

      # Skill name (defaults to class name).
      def name
        self.class.name || self.class.to_s
      end

      # Skill description (declare via the class-level `description` macro; falls back to class name).
      def description
        self.class.description || self.class.to_s
      end

      # List of parameter definitions for this skill.
      def param_definitions
        self.class.params
      end

      private

      # Real DhanHQ::Models::OptionChain#fetch shape: { last_price:, strikes: [{ strike:, call: {...}, put: {...} }] }.
      # Nearest strike to a target price — always returns an entry (never nil) unless the chain is empty.
      def nearest_strike(chain, target_price)
        strikes = chain[:strikes]
        return nil if strikes.nil? || strikes.empty?

        strikes.min_by { |s| (s[:strike].to_f - target_price.to_f).abs }
      end

      # Exact strike match within tolerance — nil if no strike sits on that price.
      def find_strike(chain, target_price, tolerance: 0.001)
        strikes = chain[:strikes]
        return nil if strikes.nil? || strikes.empty?

        strikes.find { |s| (s[:strike].to_f - target_price.to_f).abs < tolerance }
      end

      def leg_side(strike_entry, option_type)
        option_type == "CE" ? strike_entry[:call] : strike_entry[:put]
      end

      def leg_security_id(strike_entry, option_type)
        leg_side(strike_entry, option_type)[:security_id]
      end

      def leg_premium(strike_entry, option_type)
        leg_side(strike_entry, option_type)[:last_price]
      end

      def build_context(args)
        ctx = {}

        self.class.params.each do |name, config|
          value = args[name] || args[name.to_s]
          value = config[:default] if value.nil? && config[:default]
          ctx[name] = value
        end

        ctx
      end
    end
  end
end
