# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::Margin do
  let(:url) { "https://api.dhan.co/v2/globalstocks/margincalculator" }
  let(:params) { { security_id: "AAPL", transaction_type: "BUY", price: 180.0, quantity: 2.0 } }

  before do
    DhanHQ.configure_with_env
    described_class.instance_variable_set(:@resource, nil)
  end

  after { described_class.instance_variable_set(:@resource, nil) }

  describe ".calculate" do
    it "reports a fundable order" do
      stub_request(:post, url)
        .to_return(status: 200,
                   body: { totalMargin: 360.0, availableBal: 1000.0, insufficientBal: 0.0, brokerage: 1.5 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      margin = described_class.calculate(params)

      expect(margin.total_margin).to eq(360.0)
      expect(margin.available_bal).to eq(1000.0)
      expect(margin).to be_sufficient
    end

    it "reports a shortfall" do
      stub_request(:post, url)
        .to_return(status: 200, body: { totalMargin: 360.0, availableBal: 100.0, insufficientBal: 260.0 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.calculate(params)).not_to be_sufficient
    end

    it "sends price and quantity as strings the way the API documents them" do
      stub_request(:post, url)
        .with(body: hash_including("price" => "180", "quantity" => "2"))
        .to_return(status: 200, body: { totalMargin: 360.0 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      described_class.calculate(params)

      expect(WebMock).to have_requested(:post, url).with(body: hash_including("price" => "180"))
    end
  end

  describe "#to_prompt" do
    it "surfaces a shortfall" do
      margin = described_class.new({ totalMargin: 360.0, insufficientBal: 260.0 }, skip_validation: true)

      expect(margin.to_prompt).to include("shortfall=$260.0")
    end
  end
end
