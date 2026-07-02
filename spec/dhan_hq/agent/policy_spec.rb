# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::Policy do
  describe ".read_only" do
    it "creates policy with read-only scopes" do
      policy = described_class.read_only

      expect(policy.scopes).to include("portfolio:read", "market:read", "orders:read")
      expect(policy.scopes).not_to include("orders:write")
    end
  end

  describe ".from_env" do
    it "reads scopes from DHANHQ_AGENT_SCOPES" do
      ENV["DHANHQ_AGENT_SCOPES"] = "portfolio:read,orders:write"
      policy = described_class.from_env

      expect(policy.scopes).to eq(%w[portfolio:read orders:write])
    end

    it "defaults to read-only scopes" do
      ENV.delete("DHANHQ_AGENT_SCOPES")
      policy = described_class.from_env

      expect(policy.scopes).to eq(DhanHQ::Agent::Policy::READ_SCOPES)
    end
  end

  describe "#allow?" do
    it "returns true for granted scopes" do
      policy = described_class.new(scopes: ["portfolio:read"])

      expect(policy.allow?("portfolio:read")).to be true
    end

    it "returns false for missing scopes" do
      policy = described_class.new(scopes: ["portfolio:read"])

      expect(policy.allow?("orders:write")).to be false
    end
  end

  describe "#require!" do
    it "returns true when scope is allowed" do
      policy = described_class.new(scopes: ["portfolio:read"])

      expect(policy.require!("portfolio:read")).to be true
    end

    it "raises when scope is missing" do
      policy = described_class.new(scopes: ["portfolio:read"])

      expect { policy.require!("orders:write") }.to raise_error(DhanHQ::Error, /Agent scope required/)
    end
  end

  describe "#require_write!" do
    it "raises when writes are not enabled" do
      ENV["DHANHQ_MCP_ENABLE_WRITES"] = "false"
      policy = described_class.new(scopes: ["orders:write"])

      expect { policy.require_write!("orders:write") }.to raise_error(DhanHQ::LiveTradingDisabledError)
    end

    it "raises when scope is missing even if writes enabled" do
      ENV["DHANHQ_MCP_ENABLE_WRITES"] = "true"
      ENV["LIVE_TRADING"] = "true"
      policy = described_class.new(scopes: ["portfolio:read"])

      expect { policy.require_write!("orders:write") }.to raise_error(DhanHQ::Error, /Agent scope required/)
    end
  end

  describe "#writes_enabled?" do
    it "returns true when both env vars are set" do
      ENV["DHANHQ_MCP_ENABLE_WRITES"] = "true"
      ENV["LIVE_TRADING"] = "true"
      policy = described_class.new(scopes: [])

      expect(policy.writes_enabled?).to be true
    end

    it "returns false when writes not enabled" do
      ENV["DHANHQ_MCP_ENABLE_WRITES"] = "false"
      ENV["LIVE_TRADING"] = "true"
      policy = described_class.new(scopes: [])

      expect(policy.writes_enabled?).to be false
    end

    it "returns false when live trading not enabled" do
      ENV["DHANHQ_MCP_ENABLE_WRITES"] = "true"
      ENV["LIVE_TRADING"] = "false"
      policy = described_class.new(scopes: [])

      expect(policy.writes_enabled?).to be false
    end
  end

  describe "scope validation" do
    it "raises on unknown scopes" do
      expect { described_class.new(scopes: ["unknown:scope"]) }.to raise_error(ArgumentError, /Unknown agent scopes/)
    end
  end
end
