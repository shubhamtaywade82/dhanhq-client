# frozen_string_literal: true

module DhanHQ
  module Agent
    # The catalogue of tools exposed to MCP clients and agent skills: what exists, at
    # what scope, at what risk, and which handler carries it out.
    #
    # Declarative on purpose — adding an endpoint means adding an entry here, a schema
    # in {DhanHQ::Agent::ToolSchemas} and a handler in {DhanHQ::Agent::ToolHandlers}.
    # {DhanHQ::Agent::ToolRegistry} consumes this and is left responsible only for
    # lookup, policy enforcement and dispatch.
    module ToolCatalogue
      extend ToolSchemas
      extend ToolHandlers

      # Version stamped on a tool definition that does not declare its own.
      DEFAULT_TOOL_VERSION = "1.0.0"

      module_function

      # Every tool, keyed by name.
      #
      # @return [Hash{String => DhanHQ::Agent::Tool}]
      def all
        build_tools
      end

      def build_tools
        (primitive_tools + global_stocks_tools + skill_tools).to_h { |tool_item| [tool_item.name, tool_item] }
      end

      def primitive_tools
        [
          tool(name: "dhan_profile", description: "Fetch Dhan profile",
               scope: "portfolio:read", risk: "read_only",
               schema: object_schema, handler: profile_handler,
               output_schema: { type: "object", properties: { client_id: { type: "string" } } }),
          tool(name: "dhan_funds", description: "Fetch fund limits",
               scope: "portfolio:read", risk: "read_only",
               schema: object_schema, handler: funds_handler,
               output_schema: { type: "object", properties: { available_balance: { type: "number" } } }),
          tool(name: "dhan_holdings", description: "List holdings",
               scope: "portfolio:read", risk: "read_only",
               schema: object_schema, handler: holdings_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_positions", description: "List positions",
               scope: "portfolio:read", risk: "read_only",
               schema: object_schema, handler: positions_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_orders", description: "List orders",
               scope: "orders:read", risk: "read_only",
               schema: object_schema, handler: orders_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_trades", description: "List trades",
               scope: "orders:read", risk: "read_only",
               schema: object_schema, handler: trades_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_search_instruments", description: "Resolve symbols to security IDs",
               scope: "market:read", risk: "read_only",
               schema: search_schema, handler: search_handler,
               output_schema: { type: "array", items: { type: "object" } },
               examples: [
                 { input: { query: "RELIANCE" }, output: "[{security_id: '2885', symbol_name: 'RELIANCE'}]" }
               ]),
          tool(name: "dhan_ltp", description: "Fetch last traded prices",
               scope: "market:read", risk: "read_only",
               schema: feed_schema, handler: ltp_handler,
               output_schema: { type: "object", additionalProperties: { type: "number" } }),
          tool(name: "dhan_quote", description: "Fetch market quotes",
               scope: "market:read", risk: "read_only",
               schema: feed_schema, handler: quote_handler,
               output_schema: { type: "object", additionalProperties: { type: "object" } }),
          tool(name: "dhan_order_preview", description: "Validate and summarize an order without placing it",
               scope: "orders:read", risk: "trade_adjacent_read",
               schema: order_schema, handler: preview_handler,
               output_schema: {
                 type: "object",
                 properties: {
                   valid: { type: "boolean" },
                   errors: { type: "array" },
                   summary: { type: "string" }
                 }
               }),
          tool(name: "dhan_place_order", description: "Place an order after external confirmation",
               scope: "orders:write", risk: "live_write",
               schema: order_schema, handler: place_order_handler,
               output_schema: { type: "object", properties: { order_id: { type: "string" } } }),
          tool(name: "dhan_cancel_order", description: "Cancel an order",
               scope: "orders:cancel", risk: "destructive_write",
               schema: cancel_schema, handler: cancel_order_handler,
               output_schema: {
                 type: "object",
                 properties: { order_id: { type: "string" }, status: { type: "string" } }
               })
        ]
      end

      # Tools for the Global Stocks (US equities) book, plus basket orders.
      #
      # Global Stocks are a separate book from domestic NSE/BSE trading, so they get
      # their own tools rather than extra flags on the domestic ones — an agent asked
      # for "my holdings" should not silently mix INR and USD positions.
      def global_stocks_tools
        [
          tool(name: "dhan_global_holdings", description: "List US stock holdings",
               scope: "portfolio:read", risk: "read_only",
               schema: object_schema, handler: global_holdings_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_global_funds", description: "Fetch US (USD) fund limits",
               scope: "portfolio:read", risk: "read_only",
               schema: object_schema, handler: global_funds_handler,
               output_schema: { type: "object", properties: { available_cash: { type: "number" } } }),
          tool(name: "dhan_global_orders", description: "List US stock orders",
               scope: "orders:read", risk: "read_only",
               schema: object_schema, handler: global_orders_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_global_trades", description: "List US stock trades",
               scope: "orders:read", risk: "read_only",
               schema: object_schema, handler: global_trades_handler,
               output_schema: { type: "array", items: { type: "object" } }),
          tool(name: "dhan_global_market_status", description: "Check whether the US market is open",
               scope: "market:read", risk: "read_only",
               schema: object_schema, handler: global_market_status_handler,
               output_schema: {
                 type: "object",
                 properties: { status: { type: "string" }, open: { type: "boolean" } }
               }),
          tool(name: "dhan_global_order_estimate",
               description: "Estimate charges and margin for a US stock order without placing it",
               scope: "orders:read", risk: "trade_adjacent_read",
               schema: global_estimate_schema, handler: global_estimate_handler,
               output_schema: {
                 type: "object",
                 properties: { total_charges: { type: "number" }, total_margin: { type: "number" } }
               }),
          tool(name: "dhan_global_place_order", description: "Place a US stock order after external confirmation",
               scope: "orders:write", risk: "live_write",
               schema: global_order_schema, handler: global_place_order_handler,
               output_schema: { type: "object", properties: { order_id: { type: "string" } } }),
          tool(name: "dhan_global_cancel_order", description: "Cancel a US stock order",
               scope: "orders:cancel", risk: "destructive_write",
               schema: cancel_schema, handler: global_cancel_order_handler,
               output_schema: { type: "object", properties: { order_id: { type: "string" } } }),
          tool(name: "dhan_multi_order", description: "Place a basket of up to 15 domestic orders in one request",
               scope: "orders:write", risk: "live_write",
               schema: multi_order_schema, handler: multi_order_handler,
               output_schema: {
                 type: "object",
                 properties: { orders: { type: "array", items: { type: "object" } } }
               })
        ]
      end

      # Exposes each registered DhanHQ::Skills::Registry strategy as an MCP tool,
      # gated by the risk/scope the skill class declares (see DhanHQ::Skills::Base).
      def skill_tools
        DhanHQ::Skills::Registry.list.map do |skill|
          klass = DhanHQ::Skills::Registry.find(skill[:name])
          tool(name: "dhan_skill_#{skill[:name]}", description: skill[:description],
               scope: klass.scope, risk: klass.risk,
               schema: skill_input_schema(skill[:params]),
               handler: ->(arguments) { DhanHQ::Skills::Registry.call(skill[:name], arguments) })
        end
      end

      # Builds a {DhanHQ::Agent::Tool}.
      #
      # Keyword-only: with nine attributes, positional order was a memory test, and a
      # transposed scope and risk would have produced a silently mis-gated tool.
      # An unknown attribute raises, so a typo cannot create a half-built tool.
      #
      # @param attributes [Hash] Any {DhanHQ::Agent::Tool} member. +version+ defaults
      #   to {DEFAULT_TOOL_VERSION}.
      # @return [DhanHQ::Agent::Tool]
      def tool(**attributes)
        Tool.new(version: DEFAULT_TOOL_VERSION, **attributes)
      end
    end
  end
end
