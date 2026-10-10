# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contract::SpecLoader do
  describe ".load" do
    it "loads the live document with its overlays applied" do
      doc = described_class.load(:live)

      expect(doc["openapi"]).to eq("3.0.1")
      # overlay 0001: docs-only endpoints present
      expect(doc["paths"]["/profile"]["get"]["operationId"]).to eq("getProfile")
      expect(doc["paths"]["/marketfeed/ltp"]["post"]["x-dhan-docs-only"]).to be(true)
      # overlay 0002: rate-limit classes attached
      expect(doc["paths"]["/orders"]["post"]["x-dhan-rate-limit-class"]).to eq("order_api")
      expect(doc["paths"]["/optionchain"]["post"]["x-dhan-rate-limit-class"]).to eq("option_chain")
    end

    it "loads the sandbox document with its quirks overlay applied" do
      doc = described_class.load(:sandbox)

      expect(doc["servers"].first["url"]).to eq("https://sandbox.dhan.co/v2")
      expect(doc["paths"]["/orders"]["post"]["x-dhan-quirks"]).to be_an(Array)
    end

    it "memoizes and freezes the loaded documents" do
      first = described_class.load(:live)
      expect(described_class.load(:live)).to equal(first)
      expect(first).to be_frozen
    end

    it "does not mutate the raw vendored document when overlaying" do
      raw = described_class.load_raw(:live)
      described_class.load(:live)

      expect(raw["paths"]).not_to have_key("/profile")
      expect(raw["paths"]["/orders"]["post"]).not_to have_key("x-dhan-rate-limit-class")
    end
  end

  describe ".apply_patch!" do
    let(:doc) { { "a" => { "b" => 1 }, "list" => [1, 2] } }

    it "adds nested members, creating intermediate objects" do
      described_class.apply_patch!(doc, [{ "op" => "add", "path" => "/x/y/z", "value" => 42 }])

      expect(doc["x"]["y"]["z"]).to eq(42)
    end

    it "escapes ~ and / in pointer tokens per RFC 6901" do
      escaped = { "paths" => { "/a~b/c" => 1 } }
      described_class.apply_patch!(escaped, [{ "op" => "replace", "path" => "/paths/~1a~0b~1c", "value" => 2 }])

      expect(escaped["paths"]["/a~b/c"]).to eq(2)
    end

    it "appends to arrays with the - token" do
      described_class.apply_patch!(doc, [{ "op" => "add", "path" => "/list/-", "value" => 3 }])

      expect(doc["list"]).to eq([1, 2, 3])
    end

    it "replaces only existing members" do
      described_class.apply_patch!(doc, [{ "op" => "replace", "path" => "/a/b", "value" => 9 }])
      expect(doc["a"]["b"]).to eq(9)

      expect do
        described_class.apply_patch!(doc, [{ "op" => "replace", "path" => "/a/missing", "value" => 9 }])
      end.to raise_error(KeyError)
    end

    it "removes members" do
      described_class.apply_patch!(doc, [{ "op" => "remove", "path" => "/a/b" }])

      expect(doc["a"]).not_to have_key("b")
    end

    it "rejects unsupported patch operations" do
      expect do
        described_class.apply_patch!(doc, [{ "op" => "copy", "from" => "/a/b", "path" => "/c" }])
      end.to raise_error(ArgumentError, /Unsupported JSON Patch op/)
    end

    it "rejects pointers that do not start with /" do
      expect do
        described_class.apply_patch!(doc, [{ "op" => "add", "path" => "a/b", "value" => 1 }])
      end.to raise_error(ArgumentError, /must start with/)
    end
  end
end
