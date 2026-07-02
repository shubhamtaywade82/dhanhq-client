# frozen_string_literal: true

module DhanHQ
  module Agent
    # Machine-readable tool metadata shared by MCP and agent skills.
    module ToolRegistry
      Tool = Struct.new(:name, :description, :scope, :risk, :schema, :handler, keyword_init: true) do
        def to_h
          { name: name, description: description, scope: scope, risk: risk, input_schema: schema }
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

      def build_tools
        [
          tool("dhan_profile", "Fetch Dhan profile", "portfolio:read", "read_only", object_schema, profile_handler),
          tool("dhan_funds", "Fetch fund limits", "portfolio:read", "read_only", object_schema, funds_handler),
          tool("dhan_holdings", "List holdings", "portfolio:read", "read_only", object_schema, holdings_handler),
          tool("dhan_positions", "List positions", "portfolio:read", "read_only", object_schema, positions_handler),
          tool("dhan_orders", "List orders", "orders:read", "read_only", object_schema, orders_handler),
          tool("dhan_trades", "List trades", "orders:read", "read_only", object_schema, trades_handler),
          tool("dhan_search_instruments", "Resolve symbols to security IDs", "market:read", "read_only", search_schema,
               search_handler),
          tool("dhan_ltp", "Fetch last traded prices", "market:read", "read_only", feed_schema, ltp_handler),
          tool("dhan_quote", "Fetch market quotes", "market:read", "read_only", feed_schema, quote_handler),
          tool("dhan_order_preview", "Validate and summarize an order without placing it", "orders:read",
               "trade_adjacent_read", order_schema, preview_handler),
          tool("dhan_place_order", "Place an order after external confirmation", "orders:write", "live_write",
               order_schema, place_order_handler),
          tool("dhan_cancel_order", "Cancel an order", "orders:cancel", "destructive_write", cancel_schema,
               cancel_order_handler)
        ].to_h { |tool_item| [tool_item.name, tool_item] }
      end

      def tool(name, description, scope, risk, schema, handler)
        Tool.new(name: name, description: description, scope: scope, risk: risk, schema: schema, handler: handler)
      end

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
          options = arguments.reject { |key, _| key == :query }
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
  end
end
