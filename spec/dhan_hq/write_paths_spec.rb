# frozen_string_literal: true

RSpec.describe DhanHQ::WritePaths do
  describe ".mutating?" do
    it "is true for order writes" do
      expect(described_class.mutating?(:post, "/v2/orders")).to be(true)
      expect(described_class.mutating?(:put, "/v2/orders/123")).to be(true)
      expect(described_class.mutating?(:delete, "/v2/orders/123")).to be(true)
      expect(described_class.mutating?(:post, "/v2/globalstocks/orders")).to be(true)
    end

    it "is true for the other state-changing surfaces" do
      expect(described_class.mutating?(:delete, "/v2/positions")).to be(true)
      expect(described_class.mutating?(:post, "/v2/killswitch")).to be(true)
      expect(described_class.mutating?(:post, "/v2/pnlExit")).to be(true)
    end

    it "is false for every GET" do
      expect(described_class.mutating?(:get, "/v2/orders")).to be(false)
    end

    it "is false for the API's read-only POSTs" do
      %w[/v2/optionchain /v2/charts/intraday /v2/marketfeed/ltp /v2/margincalculator].each do |path|
        expect(described_class.mutating?(:post, path)).to be(false)
      end
    end

    it "is false for a nil path" do
      expect(described_class.mutating?(:post, nil)).to be(false)
    end
  end

  describe ".order_placement?" do
    it "is true only for POSTs that create orders" do
      expect(described_class.order_placement?(:post, "/v2/orders")).to be(true)
      expect(described_class.order_placement?(:post, "/v2/super/orders")).to be(true)
      expect(described_class.order_placement?(:post, "/v2/globalstocks/orders")).to be(true)
    end

    it "is false for a modification or cancellation" do
      expect(described_class.order_placement?(:put, "/v2/orders/123")).to be(false)
      expect(described_class.order_placement?(:delete, "/v2/orders/123")).to be(false)
    end

    it "is false for a non-order write" do
      expect(described_class.order_placement?(:post, "/v2/killswitch")).to be(false)
    end
  end

  describe ".multi_order?" do
    it "recognises the basket endpoint" do
      expect(described_class.multi_order?("/v2/alerts/multi/orders")).to be(true)
    end

    it "does not confuse it with a single conditional order" do
      expect(described_class.multi_order?("/v2/alerts/orders")).to be(false)
    end
  end
end
