# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::OrderEstimate do
  let(:url) { "https://api.dhan.co/v2/globalstocks/transEstimate" }
  let(:params) { { security_id: "AAPL", transaction_type: "BUY", price: 180.0, quantity: 1.0 } }

  before do
    DhanHQ.configure_with_env
    described_class.instance_variable_set(:@resource, nil)
  end

  after { described_class.instance_variable_set(:@resource, nil) }

  describe ".calculate" do
    it "totals the charge components" do
      stub_request(:post, url)
        .to_return(status: 200,
                   body: { brokerage: 1.5, exchangeCharges: 0.2, turnOverFee: 0.05,
                           gstCharges: 0.3, otherCharges: 0.1 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      estimate = described_class.calculate(params)

      expect(estimate.brokerage).to eq(1.5)
      expect(estimate.total_charges).to eq(2.15)
    end

    it "is aliased as .estimate" do
      stub_request(:post, url)
        .to_return(status: 200, body: { brokerage: 1.5 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.estimate(params).brokerage).to eq(1.5)
    end
  end

  describe "#total_charges" do
    it "ignores missing components" do
      expect(described_class.new({ brokerage: 1.5 }, skip_validation: true).total_charges).to eq(1.5)
    end

    it "is zero when the API returns nothing" do
      expect(described_class.new({}, skip_validation: true).total_charges).to eq(0.0)
    end
  end
end
