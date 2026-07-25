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
          tool("dhan_profile", "Fetch Dhan profile", "portfolio:read", "read_only",
               object_schema, profile_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { client_id: { type: "string" } } }),
          tool("dhan_funds", "Fetch fund limits", "portfolio:read", "read_only",
               object_schema, funds_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { available_balance: { type: "number" } } }),
          tool("dhan_holdings", "List holdings", "portfolio:read", "read_only",
               object_schema, holdings_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_positions", "List positions", "portfolio:read", "read_only",
               object_schema, positions_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_orders", "List orders", "orders:read", "read_only",
               object_schema, orders_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_trades", "List trades", "orders:read", "read_only",
               object_schema, trades_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_search_instruments", "Resolve symbols to security IDs", "market:read", "read_only",
               search_schema, search_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } },
               examples: [
                 { input: { query: "RELIANCE" }, output: "[{security_id: '2885', symbol_name: 'RELIANCE'}]" }
               ]),
          tool("dhan_ltp", "Fetch last traded prices", "market:read", "read_only",
               feed_schema, ltp_handler,
               version: "1.0.0",
               output_schema: { type: "object", additionalProperties: { type: "number" } }),
          tool("dhan_quote", "Fetch market quotes", "market:read", "read_only",
               feed_schema, quote_handler,
               version: "1.0.0",
               output_schema: { type: "object", additionalProperties: { type: "object" } }),
          tool("dhan_order_preview", "Validate and summarize an order without placing it", "orders:read",
               "trade_adjacent_read", order_schema, preview_handler,
               version: "1.0.0",
               output_schema: {
                 type: "object",
                 properties: {
                   valid: { type: "boolean" },
                   errors: { type: "array" },
                   summary: { type: "string" }
                 }
               }),
          tool("dhan_place_order", "Place an order after external confirmation", "orders:write", "live_write",
               order_schema, place_order_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { order_id: { type: "string" } } }),
          tool("dhan_cancel_order", "Cancel an order", "orders:cancel", "destructive_write",
               cancel_schema, cancel_order_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { order_id: { type: "string" }, status: { type: "string" } } })
        ]
      end

      # Tools for the Global Stocks (US equities) book, plus basket orders.
      #
      # Global Stocks are a separate book from domestic NSE/BSE trading, so they get
      # their own tools rather than extra flags on the domestic ones — an agent asked
      # for "my holdings" should not silently mix INR and USD positions.
      def global_stocks_tools
        [
          tool("dhan_global_holdings", "List US stock holdings", "portfolio:read", "read_only",
               object_schema, global_holdings_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_global_funds", "Fetch US (USD) fund limits", "portfolio:read", "read_only",
               object_schema, global_funds_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { available_cash: { type: "number" } } }),
          tool("dhan_global_orders", "List US stock orders", "orders:read", "read_only",
               object_schema, global_orders_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_global_trades", "List US stock trades", "orders:read", "read_only",
               object_schema, global_trades_handler,
               version: "1.0.0",
               output_schema: { type: "array", items: { type: "object" } }),
          tool("dhan_global_market_status", "Check whether the US market is open", "market:read", "read_only",
               object_schema, global_market_status_handler,
               version: "1.0.0",
               output_schema: {
                 type: "object",
                 properties: { status: { type: "string" }, open: { type: "boolean" } }
               }),
          tool("dhan_global_order_estimate", "Estimate charges and margin for a US stock order without placing it",
               "orders:read", "trade_adjacent_read", global_estimate_schema, global_estimate_handler,
               version: "1.0.0",
               output_schema: {
                 type: "object",
                 properties: { total_charges: { type: "number" }, total_margin: { type: "number" } }
               }),
          tool("dhan_global_place_order", "Place a US stock order after external confirmation",
               "orders:write", "live_write", global_order_schema, global_place_order_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { order_id: { type: "string" } } }),
          tool("dhan_global_cancel_order", "Cancel a US stock order", "orders:cancel", "destructive_write",
               cancel_schema, global_cancel_order_handler,
               version: "1.0.0",
               output_schema: { type: "object", properties: { order_id: { type: "string" } } }),
          tool("dhan_multi_order", "Place a basket of up to 15 domestic orders in one request",
               "orders:write", "live_write", multi_order_schema, multi_order_handler,
               version: "1.0.0",
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
          tool("dhan_skill_#{skill[:name]}", skill[:description], klass.scope, klass.risk,
               skill_input_schema(skill[:params]),
               ->(arguments) { DhanHQ::Skills::Registry.call(skill[:name], arguments) },
               version: "1.0.0")
        end
      end

      # Builds a {DhanHQ::Agent::Tool}. The four leading positionals are the ones every
      # tool must state — what it is called, what it does, and what it is allowed to do.
      # rubocop:disable Metrics/ParameterLists
      def tool(name, description, scope, risk, schema, handler, version: "1.0.0", output_schema: nil, examples: nil)
        Tool.new(
          name: name, description: description, scope: scope, risk: risk,
          schema: schema, handler: handler, version: version,
          output_schema: output_schema, examples: examples
        )
      end
      # rubocop:enable Metrics/ParameterLists
    end
  end
end
