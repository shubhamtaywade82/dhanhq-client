# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::Holding do
  let(:url) { "https://api.dhan.co/v2/globalstocks/holdings" }

  let(:payload) do
    {
      tradingSymbol: "AAPL",
      securityId: "AAPL",
      quantity: 2.5,
      avgCostPrice: 160.0,
      costValue: 400.0,
      currentValue: 450.0,
      gainValue: 50.0,
      ltp: 180.0,
      prevClose: 178.0
    }
  end

  before do
    DhanHQ.configure_with_env
    described_class.instance_variable_set(:@resource, nil)
  end

  after { described_class.instance_variable_set(:@resource, nil) }

  describe ".all" do
    it "maps the response to models" do
      stub_request(:get, url)
        .to_return(status: 200, body: [payload].to_json, headers: { "Content-Type" => "application/json" })

      holding = described_class.all.first

      expect(holding.trading_symbol).to eq("AAPL")
      expect(holding.quantity).to eq(2.5)
    end

    it "returns an empty array when the account holds no US stock" do
      stub_request(:get, url)
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.all).to eq([])
    end
  end

  describe "valuation helpers" do
    it "computes gain percentage against cost value" do
      expect(described_class.new(payload, skip_validation: true).gain_percentage).to eq(12.5)
    end

    it "returns 0.0 gain percentage when cost value is unknown" do
      expect(described_class.new(payload.merge(costValue: 0), skip_validation: true).gain_percentage).to eq(0.0)
    end

    it "reports profitability" do
      expect(described_class.new(payload, skip_validation: true)).to be_profitable
      expect(described_class.new(payload.merge(gainValue: -5.0), skip_validation: true)).not_to be_profitable
    end

    it "detects a fractional position" do
      expect(described_class.new(payload, skip_validation: true)).to be_fractional
      expect(described_class.new(payload.merge(quantity: 2.0), skip_validation: true)).not_to be_fractional
    end

    it "computes the change against previous close" do
      expect(described_class.new(payload, skip_validation: true).day_change).to eq(2.0)
    end

    it "returns nil day change when a price is missing" do
      expect(described_class.new(payload.except(:prevClose), skip_validation: true).day_change).to be_nil
    end
  end

  describe "portfolio aggregates" do
    before do
      stub_request(:get, url)
        .to_return(status: 200, body: [payload, payload].to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "sums market value" do
      expect(described_class.total_current_value).to eq(900.0)
    end

    it "sums unrealised gain" do
      expect(described_class.total_gain).to eq(100.0)
    end
  end

  describe "#to_prompt" do
    it "summarizes the holding in USD" do
      expect(described_class.new(payload, skip_validation: true).to_prompt).to include("AAPL", "$160.0")
    end
  end
end
