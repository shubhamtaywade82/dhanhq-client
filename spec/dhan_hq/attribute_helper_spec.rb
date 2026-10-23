# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::AttributeHelper do
  let(:helper_class) do
    Class.new do
      include DhanHQ::AttributeHelper
    end
  end
  let(:helper) { helper_class.new }

  describe "#camelize_keys" do
    it "converts snake_case symbol keys to camelCase strings" do
      result = helper.camelize_keys({ foo_bar: 1, baz_qux: 2 })
      expect(result).to include("fooBar" => 1, "bazQux" => 2)
    end

    it "converts snake_case string keys to camelCase strings" do
      result = helper.camelize_keys({ "foo_bar" => 1 })
      expect(result).to include("fooBar" => 1)
    end

    it "leaves already-camelCase keys unchanged" do
      result = helper.camelize_keys({ "fooBar" => 1 })
      expect(result).to include("fooBar" => 1)
    end

    it "returns an empty hash for an empty input" do
      expect(helper.camelize_keys({})).to eq({})
    end
  end

  describe "#titleize_keys" do
    it "converts snake_case keys to TitleCase strings without spaces" do
      result = helper.titleize_keys({ foo_bar: 1 })
      expect(result).to include("FooBar" => 1)
    end

    it "handles single-word keys" do
      result = helper.titleize_keys({ name: "value" })
      expect(result).to include("Name" => "value")
    end

    it "returns an empty hash for empty input" do
      expect(helper.titleize_keys({})).to eq({})
    end
  end

  describe "#snake_case" do
    it "converts camelCase string keys to snake_case symbols" do
      result = helper.snake_case({ "fooBar" => 1, "bazQux" => 2 })
      expect(result).to include(foo_bar: 1, baz_qux: 2)
    end

    it "converts TitleCase string keys to snake_case symbols" do
      result = helper.snake_case({ "FooBar" => 1 })
      expect(result).to include(foo_bar: 1)
    end

    it "preserves already snake_case keys as symbols" do
      result = helper.snake_case({ "foo_bar" => 1 })
      expect(result).to include(foo_bar: 1)
    end

    it "returns an empty hash for empty input" do
      expect(helper.snake_case({})).to eq({})
    end
  end

  describe "#normalize_keys" do
    it "makes values accessible by both original string and snake_case key" do
      result = helper.normalize_keys({ "fooBar" => 42 })
      expect(result["fooBar"]).to eq(42)
      expect(result["foo_bar"]).to eq(42)
    end

    it "returns a HashWithIndifferentAccess" do
      result = helper.normalize_keys({ "key" => "val" })
      expect(result).to be_a(HashWithIndifferentAccess)
    end

    it "handles symbol keys" do
      result = helper.normalize_keys({ foo_bar: "x" })
      expect(result["foo_bar"]).to eq("x")
    end

    it "returns empty HashWithIndifferentAccess for empty input" do
      result = helper.normalize_keys({})
      expect(result).to be_empty
    end
  end
end
