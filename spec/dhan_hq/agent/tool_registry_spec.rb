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

    it "includes dhan_skill_iron_condor with trade_adjacent_read risk" do
      tool = described_class.find("dhan_skill_iron_condor")

      expect(tool.scope).to eq("orders:read")
      expect(tool.risk).to eq("trade_adjacent_read")
    end

    it "includes dhan_skill_square_off_all with destructive_write risk" do
      tool = described_class.find("dhan_skill_square_off_all")

      expect(tool.scope).to eq("orders:write")
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

    it "executes a skill tool end-to-end" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["orders:read"])
      # rubocop:disable RSpec/VerifiedDoubles
      instrument = double("instrument", ltp: { ltp: 24_500.0 }, option_chain: [
                            { strike: 24_000, option_type: "PE", security_id: "PE01" },
                            { strike: 24_200, option_type: "PE", security_id: "PE02" },
                            { strike: 24_400, option_type: "PE", security_id: "PE03" },
                            { strike: 24_500, option_type: "PE", security_id: "PE04" },
                            { strike: 24_600, option_type: "CE", security_id: "CE01" },
                            { strike: 24_800, option_type: "CE", security_id: "CE02" },
                            { strike: 25_000, option_type: "CE", security_id: "CE03" }
                          ])
      # rubocop:enable RSpec/VerifiedDoubles
      allow(DhanHQ::Models::Instrument).to receive(:find).and_return(instrument)

      result = described_class.execute("dhan_skill_iron_condor", { symbol: "NIFTY", expiry: "2026-01-30" }, policy: policy)

      expect(result[:intent][:trade_type]).to eq("IRON_CONDOR")
    end

    it "raises on policy violation for skill tools without write scope" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["portfolio:read"])

      expect do
        described_class.execute("dhan_skill_square_off_all", {}, policy: policy)
      end.to raise_error(DhanHQ::Error, /Agent scope required/)
    end
  end
end
