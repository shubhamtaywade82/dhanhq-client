# frozen_string_literal: true

module DhanHQ
  module Agent
    # A single tool exposed to MCP clients and agent skills.
    #
    # - +name+, +description+ — what a client sees in `tools/list`
    # - +scope+ — the {DhanHQ::Agent::Policy} scope required to call it
    # - +risk+ — +read_only+, +trade_adjacent_read+, +live_write+ or +destructive_write+;
    #   anything ending in +write+ goes through `Policy#require_write!`
    # - +schema+, +output_schema+ — JSON Schema for input and return value
    # - +handler+ — callable invoked with symbolized arguments
    # - +version+ — semantic version of this tool definition
    # - +examples+ — optional input/output pairs shown to clients
    Tool = Struct.new(:name, :description, :scope, :risk, :schema, :handler,
                      :version, :output_schema, :examples) do
      # @return [Hash] Client-facing metadata, omitting unset optional fields.
      def to_h
        {
          name: name,
          description: description,
          scope: scope,
          risk: risk,
          input_schema: schema,
          output_schema: output_schema,
          version: version,
          examples: examples
        }.compact
      end

      # @return [Boolean] True when calling this tool changes account state.
      def write?
        risk.to_s.end_with?("write")
      end
    end
  end
end
