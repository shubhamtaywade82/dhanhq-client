# frozen_string_literal: true

require "dhan_hq"

RSpec.describe DhanHQ::SandboxCapabilities do
  describe ".unsupported?" do
    it "blocks super orders for every verb" do
      expect(described_class.unsupported?(:post, "/v2/super/orders")).to be(true)
      expect(described_class.unsupported?(:get, "/v2/super/orders")).to be(true)
      expect(described_class.unsupported?(:put, "/v2/super/orders/123")).to be(true)
      expect(described_class.unsupported?(:delete, "/v2/super/orders/123/ENTRY_LEG")).to be(true)
    end

    it "blocks alerts (conditional triggers and multi orders)" do
      expect(described_class.unsupported?(:post, "/v2/alerts/orders")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/alerts/multi/orders")).to be(true)
      expect(described_class.unsupported?(:get, "/v2/alerts/orders/abc")).to be(true)
    end

    it "blocks the sandbox-absent data tiers" do
      expect(described_class.unsupported?(:post, "/v2/marketfeed/ltp")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/optionchain")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/optionchain/expirylist")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/data/companyinfo")).to be(true)
      expect(described_class.unsupported?(:get, "/v2/instrument/NSE_EQ")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/charts/rollingoption")).to be(true)
    end

    it "blocks pnlExit, static IP, multi-scrip margin and global stocks" do
      expect(described_class.unsupported?(:post, "/v2/pnlExit")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/ip/setIP")).to be(true)
      expect(described_class.unsupported?(:get, "/v2/ip/getIP")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/margincalculator/multi")).to be(true)
      expect(described_class.unsupported?(:get, "/v2/globalstocks/orders")).to be(true)
    end

    it "blocks only the method-specific gaps: DELETE /v2/positions and GET /v2/killswitch" do
      expect(described_class.unsupported?(:delete, "/v2/positions")).to be(true)
      expect(described_class.unsupported?(:get, "/v2/positions")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/positions/convert")).to be(false)

      expect(described_class.unsupported?(:get, "/v2/killswitch")).to be(true)
      expect(described_class.unsupported?(:post, "/v2/killswitch?killSwitchStatus=ACTIVATE")).to be(false)
    end

    it "allows the endpoints the sandbox implements" do
      expect(described_class.unsupported?(:post, "/v2/orders")).to be(false)
      expect(described_class.unsupported?(:get, "/v2/orders")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/orders/slicing")).to be(false)
      expect(described_class.unsupported?(:get, "/v2/trades")).to be(false)
      expect(described_class.unsupported?(:get, "/v2/positions")).to be(false)
      expect(described_class.unsupported?(:get, "/v2/holdings")).to be(false)
      expect(described_class.unsupported?(:get, "/v2/fundlimit")).to be(false)
      expect(described_class.unsupported?(:get, "/v2/ledger")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/margincalculator")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/edis/form")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/charts/historical")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/charts/intraday")).to be(false)
      expect(described_class.unsupported?(:post, "/v2/forever/orders")).to be(false)
    end
  end

  describe ".reason_for" do
    it "explains the rule that matched" do
      expect(described_class.reason_for(:post, "/v2/marketfeed/ltp"))
        .to include("POST /v2/marketfeed*")
      expect(described_class.reason_for(:post, "/v2/orders")).to be_nil
    end
  end
end
