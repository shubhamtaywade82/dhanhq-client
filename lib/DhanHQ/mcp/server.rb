# frozen_string_literal: true

require "json"
require_relative "../agent"
require_relative "../ai"

module DhanHQ
  module MCP
    # Minimal MCP-compatible stdio JSON-RPC server for DhanHQ agent tools.
    class Server
      RESOURCES = [
        { uri: "dhanhq://account/profile", name: "Dhan Profile", description: "Current account profile including client ID, PAN, name, and trading permissions",
          mimeType: "application/json" },
        { uri: "dhanhq://account/funds", name: "Fund Limits", description: "Available balance, used margin, and withdrawal capacity", mimeType: "application/json" },
        { uri: "dhanhq://account/holdings", name: "Portfolio Holdings", description: "Current equity holdings with quantity, average price, and P&L", mimeType: "application/json" },
        { uri: "dhanhq://account/positions", name: "Open Positions", description: "Current F&O and equity positions with net quantity and unrealized P&L",
          mimeType: "application/json" },
        { uri: "dhanhq://account/orders", name: "Recent Orders", description: "Recent order history with status, quantity, and fill details", mimeType: "application/json" },
        { uri: "dhanhq://market/capabilities", name: "Agent Capabilities", description: "All available tools, scopes, risk levels, and version info", mimeType: "application/json" }
      ].freeze

      PROMPTS = [
        { name: "portfolio_summary", description: "Generate a human-readable summary of your current portfolio, positions, and available funds" },
        { name: "market_analysis", description: "Analyze current market conditions and generate a trading context summary" },
        { name: "risk_report", description: "Review current risk exposure including open positions, P&L, and position limits" },
        { name: "suggest_strategy", description: "Suggest a trading strategy based on current portfolio and market conditions" },
        { name: "order_preview", description: "Preview an order before placing it with risk validation" }
      ].freeze

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
            capabilities: { tools: {}, resources: {}, prompts: {} }
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
        when "resources/list"
          { resources: resource_definitions }
        when "resources/read"
          resource = resources.find { |r| r[:uri] == params["uri"] }
          raise ArgumentError, "Unknown resource: #{params["uri"]}" unless resource

          { contents: [resource_read(resource)] }
        when "prompts/list"
          { prompts: prompt_definitions }
        when "prompts/get"
          prompt = prompts.find { |p| p[:name] == params["name"] }
          raise ArgumentError, "Unknown prompt: #{params["name"]}" unless prompt

          prompt_result(prompt, params.fetch("arguments", {}))
        else
          raise ArgumentError, "Unsupported MCP method: #{method}"
        end
      end

      def resources
        RESOURCES
      end

      def prompts
        PROMPTS
      end

      def resource_definitions
        RESOURCES.map { |r| r.except(:handler) }
      end

      def resource_read(resource)
        handler = resource_handler(resource[:uri])
        data = handler.call
        { uri: resource[:uri], mimeType: "application/json", text: JSON.pretty_generate(serialize(data)) }
      end

      def resource_handler(uri)
        case uri
        when "dhanhq://account/profile" then -> { DhanHQ::Models::Profile.fetch }
        when "dhanhq://account/funds" then -> { DhanHQ::Models::Funds.fetch }
        when "dhanhq://account/holdings" then -> { DhanHQ::Models::Holding.all }
        when "dhanhq://account/positions" then -> { DhanHQ::Models::Position.all }
        when "dhanhq://account/orders" then -> { DhanHQ::Models::Order.all }
        when "dhanhq://market/capabilities" then -> { DhanHQ::Agent::ToolRegistry.capabilities }
        else raise ArgumentError, "No handler for resource: #{uri}"
        end
      end

      def prompt_definitions
        PROMPTS.map { |p| { name: p[:name], description: p[:description], arguments: prompt_arguments(p[:name]) } }
      end

      def prompt_arguments(prompt_name)
        case prompt_name
        when "order_preview"
          [{ name: "transaction_type", description: "BUY or SELL", required: true },
           { name: "security_id", description: "Dhan security ID", required: true },
           { name: "quantity", description: "Number of shares/lots", required: true },
           { name: "exchange_segment", description: "NSE_EQ, NSE_FNO, etc.", required: true },
           { name: "price", description: "Limit price (optional for MARKET)", required: false }]
        when "market_analysis"
          [{ name: "symbol", description: "Ticker symbol (e.g., NIFTY, RELIANCE)", required: false }]
        else
          []
        end
      end

      def prompt_result(prompt, arguments)
        case prompt[:name]
        when "portfolio_summary"
          holdings = DhanHQ::Models::Holding.all
          positions = DhanHQ::Models::Position.all
          funds = DhanHQ::Models::Funds.fetch
          summary = DhanHQ::AI::PromptHelpers.portfolio_summary(holdings: holdings, positions: positions, funds: funds)
          { messages: [{ role: "user", content: { type: "text", text: summary } }] }
        when "market_analysis"
          symbol = arguments["symbol"] || "NIFTY"
          snapshot = DhanHQ::Models::MarketFeed.quote(DhanHQ::Constants::ExchangeSegment::IDX_I => [symbol])
          text = "Market snapshot for #{symbol}: #{snapshot}"
          { messages: [{ role: "user", content: { type: "text", text: text } }] }
        when "risk_report"
          positions = DhanHQ::Models::Position.all
          text = DhanHQ::AI::PromptHelpers.risk_report(positions: positions)
          { messages: [{ role: "user", content: { type: "text", text: text } }] }
        when "order_preview"
          preview = DhanHQ::Agent::OrderPreview.new(arguments)
          text = preview.valid? ? "Order preview: #{preview.to_h[:summary]}" : "Validation errors: #{preview.errors.join(", ")}"
          { messages: [{ role: "user", content: { type: "text", text: text } }] }
        when "suggest_strategy"
          positions = DhanHQ::Models::Position.all
          funds = DhanHQ::Models::Funds.fetch
          text = "Current portfolio: #{positions.size} open positions, Available: ₹#{funds.available_balance}. Review positions for strategy suggestions."
          { messages: [{ role: "user", content: { type: "text", text: text } }] }
        else
          raise ArgumentError, "Unknown prompt: #{prompt[:name]}"
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
