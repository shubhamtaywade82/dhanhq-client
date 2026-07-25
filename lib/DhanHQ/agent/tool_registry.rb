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

      def skill_input_schema(params)
        properties = params.transform_values do |config|
          { type: skill_param_type(config[:type]) }.tap { |h| h[:description] = config[:description] if config[:description] }
        end
        required = params.select { |_, config| config[:required] }.keys.map(&:to_s)
        { type: "object", properties: properties, required: required, additionalProperties: false }
      end

      def skill_param_type(type)
        { string: "string", integer: "integer", number: "number", boolean: "boolean" }.fetch(type.to_sym, "string")
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

      # Global Stocks orders carry no exchange segment, product type or validity, and
      # quantity is fractional. AMOUNT orders replace quantity with a dollar amount.
      def global_order_schema
        {
          type: "object",
          required: %w[transaction_type order_type security_id],
          properties: {
            transaction_type: enum(%w[BUY SELL]),
            order_type: enum(DhanHQ::Constants::GlobalStocks::OrderType::ALL),
            security_id: { type: "string" },
            quantity: { type: "number", exclusiveMinimum: 0 },
            price: { type: "number", minimum: 0 },
            trigger_price: { type: "number" },
            stop_loss_price: { type: "number" },
            target_price: { type: "number" },
            amount: { type: "number", description: "Dollar value for AMOUNT orders" },
            correlation_id: { type: "string" }
          },
          additionalProperties: true
        }
      end

      def global_estimate_schema
        {
          type: "object",
          required: %w[security_id transaction_type price quantity],
          properties: {
            security_id: { type: "string" },
            transaction_type: enum(%w[BUY SELL]),
            price: { type: "number", minimum: 0 },
            quantity: { type: "number", exclusiveMinimum: 0 }
          },
          additionalProperties: false
        }
      end

      def multi_order_schema
        {
          type: "object",
          required: ["orders"],
          properties: {
            orders: {
              type: "array",
              minItems: 1,
              maxItems: DhanHQ::Contracts::MultiOrderContract::MAX_ORDERS,
              items: {
                type: "object",
                required: %w[sequence transaction_type exchange_segment],
                properties: {
                  sequence: { type: "string" },
                  transaction_type: enum(%w[BUY SELL]),
                  exchange_segment: { type: "string" },
                  product_type: { type: "string" },
                  order_type: { type: "string" },
                  validity: { type: "string" },
                  security_id: { type: "string" },
                  quantity: { type: "integer", minimum: 1 },
                  price: { type: "number" },
                  trigger_price: { type: "number" }
                },
                additionalProperties: true
              }
            }
          },
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

      def place_order_handler
        lambda do |arguments|
          instrument = DhanHQ::Models::Instrument.find_by_security_id(arguments[:exchange_segment], arguments[:security_id])
          unless instrument
            raise DhanHQ::RiskViolation,
                  "Cannot verify risk for unknown instrument: #{arguments[:exchange_segment]}:#{arguments[:security_id]}"
          end

          risk_type = instrument.instrument_type.to_s.start_with?("OPT") ? :options : :equity
          DhanHQ::Risk::Pipeline.run!(instrument: instrument, args: stringify(arguments), type: risk_type)

          DhanHQ::Models::Order.place(arguments)
        end
      end

      def cancel_order_handler
        lambda do |arguments|
          order = DhanHQ::Models::Order.find(arguments[:order_id])
          order&.cancel || false
        end
      end

      def global_holdings_handler = ->(_) { DhanHQ::Models::GlobalStocks::Holding.all }

      def global_funds_handler = ->(_) { DhanHQ::Models::GlobalStocks::Funds.fetch }

      def global_orders_handler = ->(_) { DhanHQ::Models::GlobalStocks::Order.all }

      def global_trades_handler = ->(_) { DhanHQ::Models::GlobalStocks::Trade.all }

      def global_market_status_handler
        lambda do |_|
          status = DhanHQ::Models::GlobalStocks::MarketStatus.fetch
          {
            status: status.status,
            open: status.open?,
            holiday: status.holiday?,
            market_open_time: status.market_open_time,
            market_close_time: status.market_close_time
          }
        end
      end

      # Combines the charge estimate and the margin requirement so an agent can decide
      # affordability in one call rather than two.
      def global_estimate_handler
        lambda do |arguments|
          estimate = DhanHQ::Models::GlobalStocks::OrderEstimate.calculate(arguments)
          margin = DhanHQ::Models::GlobalStocks::Margin.calculate(arguments)
          {
            total_charges: estimate.total_charges,
            brokerage: estimate.brokerage,
            total_margin: margin.total_margin,
            available_balance: margin.available_bal,
            sufficient: margin.sufficient?
          }
        end
      end

      # No {DhanHQ::Risk::Pipeline} run here: its checks resolve instruments from the
      # Indian scrip master and encode NSE/BSE rules, neither of which applies to US
      # equities. The LIVE_TRADING gate and audit logging in the resource still apply,
      # as does {Policy#require_write!}.
      def global_place_order_handler = ->(arguments) { DhanHQ::Models::GlobalStocks::Order.place(arguments) }

      def global_cancel_order_handler
        lambda do |arguments|
          order_id = arguments[:order_id]
          { order_id: order_id, cancelled: DhanHQ::Models::GlobalStocks::Order.cancel(order_id) }
        end
      end

      def multi_order_handler = ->(arguments) { DhanHQ::Models::MultiOrder.place(arguments[:orders]) }

      def symbolize(value)
        case value
        when Hash then value.each_with_object({}) { |(key, val), hash| hash[key.to_sym] = symbolize(val) }
        when Array then value.map { |val| symbolize(val) }
        else value
        end
      end

      def stringify(value)
        case value
        when Hash then value.each_with_object({}) { |(key, val), hash| hash[key.to_s] = stringify(val) }
        when Array then value.map { |val| stringify(val) }
        else value
        end
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
