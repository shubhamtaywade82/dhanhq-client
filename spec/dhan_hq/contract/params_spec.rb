# frozen_string_literal: true

require "yaml"

# Method-parameter kinds that carry user input (method.parameters pairs).
PARAMETER_KINDS = %i[req opt key keyreq].freeze

RSpec.describe DhanHQ::Contract::Params do
  # One example per generated class keeps failures local to the schema that
  # caused them; the loop bodies assert the full structural parity triangle
  # (generated struct <-> vendored schema <-> operation registry).
  describe "generated structs <-> vendored contract parity" do
    it "maps every operation with a request schema to a struct class" do
      expected = DhanHQ::Contract::Registry.operations.values
                                           .select(&:request_schema_name)
                                           .map { |op| [op.id, op.request_schema_name] }
      expect(expected).not_to be_empty

      expected.each do |op_id, schema_name|
        class_name = described_class::OPERATION_PARAMS[op_id]
        expect(class_name).to eq(params_class_name(schema_name)),
                              "operation #{op_id} should map to #{params_class_name(schema_name)}, got #{class_name.inspect}"
      end
    end

    it "keeps every struct's fields in lockstep with its schema" do
      described_class::OPERATION_PARAMS.each do |op_id, class_name|
        klass = described_class.const_get(class_name)
        schema = DhanHQ::Contract::Registry.live_schemas.fetch(klass.schema_name)
        props = schema.fetch("properties")
        required = (schema["required"] || []) - klass::INJECTED_FIELDS

        expect(klass.operation_ids).to include(op_id)
        expect(klass.wire_key_map.keys.sort).to eq(props.keys.sort),
                                                "#{class_name}: wire keys must mirror the schema properties exactly"
        expect(klass.wire_key_map.values.sort).to eq(klass.fields.keys.sort),
                                                  "#{class_name}: wire-key map must cover every struct field"
        expect(klass.required_fields.sort).to eq(required.map(&:underscore).sort),
                                              "#{class_name}: required list must match the schema (minus injected fields)"

        props.each do |wire_key, spec|
          field = klass.fields[wire_key.underscore]
          type = Array(spec["type"]).join("|")
          expect(field["type"]).to eq(type.empty? ? nil : type),
                                   "#{class_name}.#{wire_key}: type drift"
          expect(field["enum"]).to eq(spec["enum"].is_a?(Array) && !spec["enum"].empty? ? spec["enum"] : nil),
                                   "#{class_name}.#{wire_key}: enum drift"
        end
      end
    end
  end

  describe "struct behaviour" do
    subject(:order) { DhanHQ::Contract::Params::OrderParams.new(**order_attrs) }

    let(:order_attrs) do
      {
        transaction_type: "BUY",
        exchange_segment: "NSE_EQ",
        product_type: "CNC",
        order_type: "LIMIT",
        security_id: "11536",
        quantity: 5
      }
    end

    it "round-trips snake_case fields through to_h" do
      expect(order.to_h).to eq(order_attrs)
      expect(order.to_h).not_to be_frozen
      expect(order).to be_frozen
    end

    it "omits nil-valued optional fields from to_h (nil means not provided)" do
      expect(order.merge(price: nil).to_h).to eq(order_attrs)
    end

    it "accepts algo_id (vendored OrderRequest field) and maps it to the algoId wire key" do
      expect(described_class::OrderParams.wire_key_map).to include("algoId" => "algo_id")
      expect(order.merge(algo_id: "1234").to_h).to include(algo_id: "1234")
    end

    it "rejects unknown fields with the known set in the message" do
      expect { DhanHQ::Contract::Params::OrderParams.new(quantitiy: 5) }
        .to raise_error(DhanHQ::ValidationError, /unknown field `quantitiy`.*exchange_segment/)
    end

    it "rejects missing required fields and names the wire key" do
      expect { DhanHQ::Contract::Params::OrderParams.new(transaction_type: "BUY") }
        .to raise_error(DhanHQ::ValidationError, /missing required field `exchange_segment`.*exchangeSegment/)
    end

    it "rejects enum violations" do
      expect { DhanHQ::Contract::Params::SuperModifyParams.new(order_type: "BOGUS", order_id: "1") }
        .to raise_error(DhanHQ::ValidationError, /must be one of LIMIT, MARKET/)
    end

    it "rejects type violations" do
      expect { order.merge(quantity: "five") }
        .to raise_error(DhanHQ::ValidationError, /field `quantity` must be integer, got String/)
    end

    it "accepts camelCase, snake_case, string and symbol keys via from_h" do
      built = DhanHQ::Contract::Params::OrderParams.from_h(
        "transactionType" => "SELL", :exchange_segment => "BSE_EQ",
        "product_type" => "CNC", :orderType => "MARKET",
        security_id: "11536", quantity: 1
      )
      expect(built.to_h).to eq(order_attrs.merge(transaction_type: "SELL", exchange_segment: "BSE_EQ",
                                                 product_type: "CNC", order_type: "MARKET",
                                                 security_id: "11536", quantity: 1))
    end

    it "is idempotent in from_h" do
      expect(DhanHQ::Contract::Params::OrderParams.from_h(order)).to eq(order)
    end

    it "revalidates on merge and returns a new struct" do
      merged = order.merge("triggerPrice" => 190.0)
      expect(merged).not_to equal(order)
      expect(merged[:trigger_price]).to eq(190.0)
      expect { order.merge(quantity: "x") }.to raise_error(DhanHQ::ValidationError)
    end

    it "exposes valid? and errors on the immutable struct" do
      expect(order).to be_valid
      expect(order.errors).to be_empty
    end

    it "revalidates on merge and raises before a struct is returned" do
      expect { order.merge(price: "abc") }.to raise_error(DhanHQ::ValidationError, /must be number/)
    end

    it "does not require injected fields (dhanClientId)" do
      expect(DhanHQ::Contract::Params::OrderParams.required_fields).not_to include("dhan_client_id")
    end

    it "supports string and wire-key readers" do
      expect(order[:security_id]).to eq("11536")
      expect(order["securityId"]).to eq("11536")
      expect(order.key?(:quantity)).to be(true)
      expect(order.key?("trailingJump")).to be(false)
    end

    it "carries the schema name and operation ids for traceability" do
      expect(DhanHQ::Contract::Params::OrderParams.schema_name).to eq("OrderRequest")
      expect(DhanHQ::Contract::Params::OrderParams.operation_ids).to contain_exactly("placeorder", "placesliceorder")
    end
  end

  describe "Params.coerce" do
    it "unwraps structs, passes hashes through, and descends into arrays" do
      struct = DhanHQ::Contract::Params::OrderParams.new(
        transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
        order_type: "LIMIT", security_id: "11536", quantity: 5
      )
      hash = { transaction_type: "SELL" }

      expect(described_class.coerce(struct)).to eq(struct.to_h)
      expect(described_class.coerce(hash)).to equal(hash)
      expect(described_class.coerce([hash, struct])).to eq([hash, struct.to_h])
      expect(described_class.coerce(nil)).to be_nil
    end
  end

  # Structural discipline: every bound resource method that takes a params
  # (or orders) argument must coerce it as its first statement, so a struct
  # never leaks past the resource boundary into Dry contracts, risk checks or
  # audit logging. Contract-driven: derived from bindings.yml, not a list.
  describe "resource coercion discipline" do
    it "coerces params in the first statement of every bound params-taking method" do
      offenders = []

      DhanHQ::Contract::Bindings.table.each do |resource_name, methods|
        klass = "DhanHQ::#{resource_name}".split("::").inject(Object) { |mod, name| mod.const_get(name) }
        methods.each_key do |method_name|
          next unless klass.method_defined?(method_name) || klass.private_method_defined?(method_name)

          method = klass.instance_method(method_name)
          param_names = method.parameters.select { |kind, _| PARAMETER_KINDS.include?(kind) }.map(&:last) # rubocop:disable Style/HashSlice -- Array#slice is not Hash#slice
          next unless param_names.intersect?(%i[params orders])

          file, line = method.source_location
          next unless file

          body = File.readlines(file, encoding: "UTF-8")[line..(line + 2)].join
          coerced = body.match?(/(?:params|orders) = contract_params\((?:params|orders)\)/)
          offenders << "#{klass}##{method_name} (#{File.basename(file)})" unless coerced
        end
      end

      expect(offenders).to be_empty,
                           "bound params-taking methods must start with `params = contract_params(params)`: #{offenders.join(", ")}"
    end
  end

  def params_class_name(schema_name)
    "#{schema_name.sub(/\A(.+?)(Request|Req|Model)\z/, '\1')}Params"
  end
end
