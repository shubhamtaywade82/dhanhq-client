# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::ToolRegistry do
  describe ".tools" do
    it "returns a hash of tool definitions" do
      tools = described_class.tools

      expect(tools).to be_a(Hash)
      expect(tools).not_to be_empty
    end

    it "includes dhan_profile tool" do
      tool = described_class.find("dhan_profile")

      expect(tool.name).to eq("dhan_profile")
      expect(tool.scope).to eq("portfolio:read")
      expect(tool.risk).to eq("read_only")
    end

    it "includes dhan_place_order tool with live_write risk" do
      tool = described_class.find("dhan_place_order")

      expect(tool.name).to eq("dhan_place_order")
      expect(tool.scope).to eq("orders:write")
      expect(tool.risk).to eq("live_write")
    end

    it "includes dhan_cancel_order tool with destructive_write risk" do
      tool = described_class.find("dhan_cancel_order")

      expect(tool.name).to eq("dhan_cancel_order")
      expect(tool.risk).to eq("destructive_write")
    end
  end

  describe ".find" do
    it "raises for unknown tools" do
      expect { described_class.find("nonexistent") }.to raise_error(ArgumentError, /Unknown DhanHQ agent tool/)
    end
  end

  describe ".list" do
    it "returns array of tool hashes" do
      list = described_class.list

      expect(list).to be_a(Array)
      expect(list.first).to include(:name, :description, :scope, :risk)
    end
  end

  describe ".capabilities" do
    it "returns capability manifest" do
      caps = described_class.capabilities

      expect(caps).to include(:version, :tool_count, :tools, :scopes, :risk_levels, :write_enabled)
      expect(caps[:tool_count]).to be > 0
    end
  end

  describe ".execute" do
    it "executes read-only tools" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["portfolio:read"])

      allow(DhanHQ::Models::Profile).to receive(:fetch).and_return({ client_id: "test" })

      result = described_class.execute("dhan_profile", {}, policy: policy)

      expect(result).to eq({ client_id: "test" })
    end

    it "raises on policy violation for write tools without write scope" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["portfolio:read"])

      expect do
        described_class.execute("dhan_place_order", { transaction_type: "BUY" }, policy: policy)
      end.to raise_error(DhanHQ::Error, /Agent scope required/)
    end
  end
end
