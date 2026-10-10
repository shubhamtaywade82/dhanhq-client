# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contract::Registry do
  describe ".operations" do
    it "indexes every live operation plus the docs-only overlays" do
      expect(described_class.operations.size).to eq(71)
      expect(described_class.operations.keys).to include("placeorder", "getProfile", "marketfeedLTP")
    end
  end

  describe ".resolve" do
    it "resolves resource-layer paths to their operations" do
      expect(described_class.resolve(:post, "/v2/orders")&.id).to eq("placeorder")
      expect(described_class.resolve(:put, "/v2/orders/OID-123")&.id).to eq("modifyorder")
      expect(described_class.resolve(:delete, "/v2/super/orders/OID/ENTRY_LEG")&.id).to eq("cancelsuperorder")
      expect(described_class.resolve(:get, "/v2/orders/external/CORR-1")&.id).to eq("getorderbycorrelationid")
      expect(described_class.resolve(:get, "/v2/trades/2026-01-01/2026-01-31/1")&.id).to eq("gettradehistory")
    end

    it "prefers literal segments over wildcard templates" do
      # /alerts/multi/orders (literal) must win over /alerts/orders/{alertId}
      expect(described_class.resolve(:post, "/v2/alerts/multi/orders")&.id).to eq("placeMultiOrder")
      expect(described_class.resolve(:delete, "/v2/alerts/orders/A-1")&.id).to eq("delAlertOrder")
    end

    it "strips query strings and tolerates trailing slashes" do
      expect(described_class.resolve(:post, "/v2/killswitch?killSwitchStatus=ACTIVATE")&.id).to eq("killswitch")
      expect(described_class.resolve(:get, "/v2/positions/")&.id).to eq("getpositions")
    end

    it "resolves docs-only overlay endpoints" do
      op = described_class.resolve(:post, "/v2/marketfeed/ltp")

      expect(op&.id).to eq("marketfeedLTP")
      expect(op).to be_docs_only
    end

    it "returns nil for endpoints the contract does not define" do
      expect(described_class.resolve(:post, "/v2/orders/iceberg")).to be_nil
      expect(described_class.resolve(:post, "/v2/orders/twap")).to be_nil
      expect(described_class.resolve(:get, "/v2/forever/orders/OID")).to be_nil
      expect(described_class.resolve(:get, "/trader-control")).to be_nil
    end

    it "keeps verb and path distinct" do
      # GET /v2/killswitch is NOT in the sandbox spec while POST is — the
      # registry must never conflate verbs on the same path.
      expect(described_class.resolve(:get, "/v2/killswitch")&.id).to eq("KillSwitchStatus")
      expect(described_class.resolve(:post, "/v2/killswitch")&.id).to eq("killswitch")
    end
  end

  describe ".sandbox_supported?" do
    it "is true exactly for the sandbox contract's operations" do
      expect(described_class.sandbox_supported?(:post, "/v2/orders")).to be(true)
      expect(described_class.sandbox_supported?(:post, "/v2/super/orders")).to be(false)
      expect(described_class.sandbox_supported?(:post, "/v2/marketfeed/ltp")).to be(false)
      expect(described_class.sandbox_supported?(:delete, "/v2/positions")).to be(false)
      expect(described_class.sandbox_supported?(:get, "/v2/positions")).to be(true)
      expect(described_class.sandbox_supported?(:post, "/v2/unknown-endpoint")).to be(false)
    end
  end

  describe "operation metadata" do
    it "attaches rate-limit classes from the overlay" do
      expect(described_class.operation("placeorder").rate_limit_class).to eq(:order_api)
      expect(described_class.operation("fundlimit").rate_limit_class).to eq(:order_api)
      expect(described_class.operation("historicalcharts").rate_limit_class).to eq(:data_api)
      expect(described_class.operation("optionchain").rate_limit_class).to eq(:option_chain)
    end

    it "declares per-operation parameter key styles instead of URL sniffing" do
      expect(described_class.operation("marketfeedLTP").param_style).to eq(:none)
      expect(described_class.operation("optionchain").param_style).to eq(:titleize)
      expect(described_class.operation("placeorder").param_style).to eq(:camelize)
    end

    it "dereferences request schemas from the live document" do
      schema = described_class.operation("placeorder").request_schema

      expect(schema["properties"]).to include("transactionType", "exchangeSegment", "securityId")
    end

    it "carries sandbox quirks for sandbox-served operations" do
      expect(described_class.operation("placeorder").quirks).to be_an(Array)
      expect(described_class.operation("fundlimit").quirks).to include(/fund limit of 500/)
    end
  end
end
