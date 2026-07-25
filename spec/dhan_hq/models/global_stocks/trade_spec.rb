# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::Trade do
  let(:url) { "https://api.dhan.co/v2/globalstocks/trades" }

  before do
    DhanHQ.configure_with_env
    described_class.instance_variable_set(:@resource, nil)
  end

  after { described_class.instance_variable_set(:@resource, nil) }

  describe ".all" do
    it "maps the trade book" do
      stub_request(:get, url)
        .to_return(status: 200,
                   body: [{ orderId: "1", tradedPrice: 180.5, tradedQuantity: 1.0, tradingSymbol: "AAPL" }].to_json,
                   headers: { "Content-Type" => "application/json" })

      trade = described_class.all.first

      expect(trade.traded_price).to eq(180.5)
      expect(trade.traded_quantity).to eq(1.0)
    end

    it "returns an empty array for a non-array response" do
      stub_request(:get, url)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect(described_class.all).to eq([])
    end
  end

  describe ".find_by_security_id" do
    it "filters by security" do
      stub_request(:get, "#{url}/AAPL")
        .to_return(status: 200, body: [{ orderId: "1", securityId: "AAPL" }].to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.find_by_security_id("AAPL").first.security_id).to eq("AAPL")
    end
  end

  describe "#total_charges" do
    it "sums brokerage and other charges" do
      trade = described_class.new({ brokerage: 1.5, otherCharges: 0.25 }, skip_validation: true)

      expect(trade.total_charges).to eq(1.75)
    end

    it "treats missing charges as zero" do
      expect(described_class.new({}, skip_validation: true).total_charges).to eq(0.0)
    end
  end

  describe "#to_prompt" do
    it "summarizes the trade" do
      trade = described_class.new(
        { transactionType: "BUY", tradedQuantity: 1.0, tradingSymbol: "AAPL", tradedPrice: 180.5 },
        skip_validation: true
      )

      expect(trade.to_prompt).to include("BUY", "AAPL", "$180.5")
    end
  end
end
