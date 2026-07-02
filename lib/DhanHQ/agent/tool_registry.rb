# frozen_string_literal: true

module DhanHQ
  module Agent
    # Machine-readable tool metadata shared by MCP and agent skills.
    #
    # Each tool has:
    # - name, description, scope, risk, schema (input), handler
    # - version: semantic version of the tool definition
    # - output_schema: JSON Schema for the tool's return value
    # - examples: array of example input/output pairs
    # rubocop:disable Metrics/ModuleLength
    module ToolRegistry
      Tool = Struct.new(:name, :description, :scope, :risk, :schema, :handler,
                        :version, :output_schema, :examples) do
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
      end

      module_function

      def tools
        @tools ||= build_tools.freeze
      end

      def find(name)
        tools.fetch(name.to_s) { raise ArgumentError, "Unknown DhanHQ agent tool: #{name}" }
      end

      def list
        tools.values.map(&:to_h)
      end

      def execute(name, arguments = {}, policy: Policy.from_env)
        tool = find(name)
        if tool.risk.to_s.end_with?("write") || tool.risk == "destructive_write"
          policy.require_write!(tool.scope)
        else
          policy.require!(tool.scope)
        end
        tool.handler.call(symbolize(arguments))
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

      def build_tools
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
        ].to_h { |tool_item| [tool_item.name, tool_item] }
      end

      # rubocop:disable Metrics/ParameterLists
      def tool(name, description, scope, risk, schema, handler, version: "1.0.0", output_schema: nil, examples: nil)
        Tool.new(
          name: name, description: description, scope: scope, risk: risk,
          schema: schema, handler: handler, version: version,
          output_schema: output_schema, examples: examples
        )
      end
      # rubocop:enable Metrics/ParameterLists

      def object_schema
        { type: "object", properties: {}, additionalProperties: false }
      end

      def search_schema
        {
          type: "object",
          required: ["query"],
          properties: {
            query: { type: "string" },
            segments: { type: "array", items: { type: "string" } },
            limit: { type: "integer", minimum: 1, maximum: 100 },
            exact_match: { type: "boolean" }
          },
          additionalProperties: false
        }
      end

      def feed_schema
        {
          type: "object",
          required: ["instruments"],
          properties: {
            instruments: {
              type: "object",
              additionalProperties: { type: "array", items: { type: %w[integer string] } }
            }
          },
          additionalProperties: false
        }
      end

      def order_schema
        {
          type: "object",
          required: %w[transaction_type exchange_segment product_type order_type validity security_id quantity],
          properties: {
            transaction_type: enum(%w[BUY SELL]),
            exchange_segment: { type: "string" },
            product_type: { type: "string" },
            order_type: { type: "string" },
            validity: { type: "string" },
            security_id: { type: "string" },
            quantity: { type: "integer", minimum: 1 },
            price: { type: "number" },
            trigger_price: { type: "number" },
            correlation_id: { type: "string" }
          },
          additionalProperties: true
        }
      end

      def cancel_schema
        {
          type: "object",
          required: ["order_id"],
          properties: { order_id: { type: "string" } },
          additionalProperties: false
        }
      end

      def enum(values)
        { type: "string", enum: values }
      end

      def profile_handler = ->(_) { DhanHQ::Models::Profile.fetch }

      def funds_handler = ->(_) { DhanHQ::Models::Funds.fetch }

      def holdings_handler = ->(_) { DhanHQ::Models::Holding.all }

      def positions_handler = ->(_) { DhanHQ::Models::Position.all }

      def orders_handler = ->(_) { DhanHQ::Models::Order.all }

      def trades_handler = ->(_) { DhanHQ::Models::Trade.today }

      def search_handler
        lambda do |arguments|
          query = arguments.fetch(:query)
          options = arguments.except(:query)
          DhanHQ::Models::Instrument.search(query, **options)
        end
      end

      def ltp_handler = ->(arguments) { DhanHQ::Models::MarketFeed.ltp(arguments[:instruments]) }

      def quote_handler = ->(arguments) { DhanHQ::Models::MarketFeed.quote(arguments[:instruments]) }

      def preview_handler = ->(arguments) { OrderPreview.new(arguments).to_h }

      def place_order_handler = ->(arguments) { DhanHQ::Models::Order.place(arguments) }

      def cancel_order_handler
        lambda do |arguments|
          order = DhanHQ::Models::Order.find(arguments[:order_id])
          order&.cancel || false
        end
      end

      def symbolize(value)
        case value
        when Hash then value.each_with_object({}) { |(key, val), hash| hash[key.to_sym] = symbolize(val) }
        when Array then value.map { |val| symbolize(val) }
        else value
        end
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
