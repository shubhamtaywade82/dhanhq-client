# frozen_string_literal: true

module DhanHQ
  module Agent
    # JSON Schema fragments describing the input each agent tool accepts.
    #
    # Pure data: no API calls, no policy, no state. Kept apart from
    # {DhanHQ::Agent::ToolRegistry} so that adding an endpoint means editing a schema
    # here and a handler in {DhanHQ::Agent::ToolHandlers}, rather than growing one
    # module that does registration, schema description and dispatch at once.
    module ToolSchemas
      module_function

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
    end
  end
end
