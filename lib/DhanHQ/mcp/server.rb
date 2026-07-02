# frozen_string_literal: true

require "json"
require_relative "../agent"

module DhanHQ
  module MCP
    # Minimal MCP-compatible stdio JSON-RPC server for DhanHQ agent tools.
    class Server
      def initialize(input: $stdin, output: $stdout, policy: DhanHQ::Agent::Policy.from_env)
        @input = input
        @output = output
        @policy = policy
      end

      def run
        @input.each_line { |line| handle_line(line) }
      end

      def handle_line(line)
        request = JSON.parse(line)
        respond(request["id"], dispatch(request["method"], request["params"] || {}))
      rescue StandardError => e
        respond(nil, nil, code: -32_000, message: e.message)
      end

      private

      def dispatch(method, params)
        case method
        when "initialize"
          {
            protocolVersion: "2024-11-05",
            serverInfo: { name: "dhanhq-ruby", version: DhanHQ::VERSION },
            capabilities: { tools: {} }
          }
        when "tools/list"
          { tools: DhanHQ::Agent::ToolRegistry.list.map { |t| mcp_tool(t) } }
        when "tools/call"
          result = DhanHQ::Agent::ToolRegistry.execute(
            params.fetch("name"),
            params.fetch("arguments", {}),
            policy: @policy
          )
          { content: [{ type: "text", text: JSON.pretty_generate(serialize(result)) }] }
        else
          raise ArgumentError, "Unsupported MCP method: #{method}"
        end
      end

      def mcp_tool(tool)
        { name: tool[:name], description: "[#{tool[:risk]}] #{tool[:description]}", inputSchema: tool[:input_schema] }
      end

      def serialize(value)
        case value
        when Array then value.map { |v| serialize(v) }
        when Hash then value.transform_values { |v| serialize(v) }
        else
          value.respond_to?(:attributes) ? value.attributes : value
        end
      end

      def respond(id, result, code: nil, message: nil)
        payload = { jsonrpc: "2.0", id: id }
        code ? payload[:error] = { code: code, message: message } : payload[:result] = result
        @output.puts(JSON.generate(payload))
        @output.flush
      end
    end
  end
end
