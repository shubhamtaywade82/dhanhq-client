# frozen_string_literal: true

require "spec_helper"

# Declared, non-silent differences: helper/derived attributes that exist only
# on the model side, keyed by model.
MODEL_ONLY_ATTRIBUTES = {
  "DhanHQ::Models::Order" => [],
  "DhanHQ::Models::Position" => [],
  "DhanHQ::Models::Holding" => []
}.freeze

# Model-layer parity: the attributes each model declares must correspond to
# properties in the contract's response schemas, and vice versa. This catches
# both "gem reads a field the API no longer sends" and "API grows a field the
# gem drops on the floor". Deltas are declared explicitly, never silent.
RSpec.describe "model attribute parity with the contract" do
  let(:schemas) { DhanHQ::Contract::Metadata::SCHEMAS }

  def schema_properties(name)
    schemas.fetch(name).fetch("properties").keys
  end

  def snake_case(camel)
    camel.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
  end

  {
    "DhanHQ::Models::Order" => "OrderResponse",
    "DhanHQ::Models::Position" => "PositionResponse",
    "DhanHQ::Models::Holding" => "HoldingResponse"
  }.each do |model_name, schema_name|
    describe model_name do
      let(:model) { Object.const_get(model_name) }
      let(:model_attrs) { model.defined_attributes.to_a.map(&:to_s) }
      let(:schema_attrs) { schema_properties(schema_name).map { |p| snake_case(p) } }

      it "declares every schema property (camelCase → snake_case)" do
        missing = schema_attrs - model_attrs - MODEL_ONLY_ATTRIBUTES.fetch(model_name)
        message = "#{schema_name} serves fields the model does not declare: #{missing.join(", ")}"

        expect(missing).to be_empty, message
      end

      it "does not declare unknown fields beyond the schema (± declared helpers)" do
        extra = model_attrs - schema_attrs
        message = "#{model_name} declares fields absent from #{schema_name}: #{extra.join(", ")}"

        expect(extra).to be_empty, message
      end
    end
  end

  it "ships metadata for the core response schemas" do
    %w[OrderResponse PositionResponse HoldingResponse OrderRequest MultiOrderItemRequest].each do |name|
      expect(schemas).to have_key(name)
    end
  end
end
