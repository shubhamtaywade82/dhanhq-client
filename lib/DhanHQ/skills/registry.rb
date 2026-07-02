# frozen_string_literal: true

module DhanHQ
  module Skills
    # Registry for skill definitions.
    #
    # Maps skill names to their classes. Skills are registered explicitly
    # or discovered via conventions.
    #
    # @example Register a skill
    #   DhanHQ::Skills::Registry.register("buy_atm_call", BuyAtmCall)
    #
    # @example Find a skill
    #   skill = DhanHQ::Skills::Registry.find("buy_atm_call")
    #   result = skill.call(symbol: "NIFTY", expiry: "2026-01-30")
    #
    class Registry
      class << self
        # Register a skill class by name.
        #
        # @param name [String] skill name
        # @param klass [Class] skill class inheriting from Base
        # @raise [ArgumentError] if the class is not a Base subclass
        def register(name, klass)
          raise ArgumentError, "Skill class must inherit from DhanHQ::Skills::Base" unless klass < Base

          skills[name.to_s] = klass
        end

        # Find a skill by name.
        #
        # @param name [String] skill name
        # @return [Class] the skill class
        # @raise [KeyError] if skill is not found
        def find(name)
          skills.fetch(name.to_s) { raise KeyError, "Unknown skill: #{name}" }
        end

        # Execute a skill by name with the given arguments.
        #
        # @param name [String] skill name
        # @param args [Hash] skill parameters
        # @return [Hash] context with all accumulated state
        def call(name, args = {})
          find(name).new.call(args)
        end

        # List all registered skill names.
        #
        # @return [Array<String>]
        def names
          skills.keys.sort
        end

        # List all registered skills with metadata.
        #
        # @return [Array<Hash>]
        def list
          skills.map do |name, klass|
            instance = klass.new
            {
              name: name,
              description: instance.description,
              params: instance.param_definitions,
              steps: klass.steps.map { |s| s[:name] }
            }
          end
        end

        # Clear all registered skills (for testing).
        def clear!
          @skills = {}
        end

        # Load built-in skills from the builtin directory and register them.
        def load_builtins
          Dir[File.join(__dir__, "builtin", "*.rb")].each do |file|
            require file
          end

          # Auto-register any Builtin classes that inherit from Base
          DhanHQ::Skills::Builtin.constants.each do |const_name|
            klass = DhanHQ::Skills::Builtin.const_get(const_name)
            next unless klass.is_a?(Class) && klass < Base

            name = const_name.to_s
                             .gsub(/([a-z])([A-Z])/, '\1_\2')
                             .downcase
            register(name, klass) unless skills.key?(name)
          end
        end

        private

        def skills
          @skills ||= {}
        end
      end
    end
  end
end
