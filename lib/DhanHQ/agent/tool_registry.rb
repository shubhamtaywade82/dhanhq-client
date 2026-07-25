# frozen_string_literal: true

module DhanHQ
  module Agent
    # Registry and dispatcher for the tools exposed to MCP clients and agent skills.
    #
    # Holds the catalogue (which tools exist, at what scope and risk) and enforces
    # {DhanHQ::Agent::Policy} on every call. The tools themselves are described by
    # {DhanHQ::Agent::ToolSchemas} and carried out by {DhanHQ::Agent::ToolHandlers};
    # each tool is a {DhanHQ::Agent::Tool}.
    module ToolRegistry
      module_function

      def tools
        @tools ||= ToolCatalogue.all.freeze
      end

      def find(name)
        tools.fetch(name.to_s) { raise ArgumentError, "Unknown DhanHQ agent tool: #{name}" }
      end

      def list
        tools.values.map(&:to_h)
      end

      def execute(name, arguments = {}, policy: Policy.from_env)
        tool = find(name)
        tool.write? ? policy.require_write!(tool.scope) : policy.require!(tool.scope)
        tool.handler.call(KeyCoercion.symbolize(arguments))
      end

      # Coerces JSON-delivered argument keys to symbols.
      # Part of this module's surface because {DhanHQ::Agent::OrderPreview} calls it.
      #
      # @param value [Hash, Array, Object]
      # @return [Hash, Array, Object]
      def symbolize(value)
        KeyCoercion.symbolize(value)
      end

      # Returns capability manifest for the agent runtime.
      # Includes tool count, available scopes, risk levels, and version info.
      def capabilities
        {
          version: DhanHQ::VERSION,
          tool_count: tools.size,
          tools: list,
          scopes: Policy::ALL_SCOPES,
          risk_levels: tools.values.map(&:risk).uniq.sort,
          write_enabled: Policy.from_env.writes_enabled?
        }
      end
    end
  end
end
