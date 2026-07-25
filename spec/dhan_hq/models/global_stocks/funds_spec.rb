# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::Funds do
  let(:url) { "https://api.dhan.co/v2/globalstocks/fundlimit" }

  before do
    DhanHQ.configure_with_env
    described_class.instance_variable_set(:@resource, nil)
    stub_request(:get, url)
      .to_return(status: 200,
                 body: { availableCash: 1500.25, settledCash: 1200.0, unsettledCash: 300.25 }.to_json,
                 headers: { "Content-Type" => "application/json" })
  end

  after { described_class.instance_variable_set(:@resource, nil) }

  describe ".fetch" do
    it "exposes the USD balance fields" do
      funds = described_class.fetch

      expect(funds.available_cash).to eq(1500.25)
      expect(funds.settled_cash).to eq(1200.0)
      expect(funds.unsettled_cash).to eq(300.25)
    end
  end

  describe ".balance" do
    it "returns the available cash" do
      expect(described_class.balance).to eq(1500.25)
    end
  end

  describe "#to_prompt" do
    it "summarizes the balance in USD" do
      expect(described_class.fetch.to_prompt).to include("available=$1500.25")
    end
  end
end
