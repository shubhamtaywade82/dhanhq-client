# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::GlobalStocks::MarginCalculator do
  subject(:resource) { described_class.new }

  let(:margin_url) { "https://api.dhan.co/v2/globalstocks/margincalculator" }
  let(:estimate_url) { "https://api.dhan.co/v2/globalstocks/transEstimate" }
  let(:params) { { security_id: "AAPL", transaction_type: "BUY", price: 180.0, quantity: 2.0 } }

  before { DhanHQ.configure_with_env }

  describe "#calculate" do
    it "POSTs with price and quantity rendered as strings" do
      stub_request(:post, margin_url)
        .with(body: hash_including("price" => "180", "quantity" => "2", "securityId" => "AAPL"))
        .to_return(status: 200, body: { totalMargin: 360.0 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(resource.calculate(params)["totalMargin"]).to eq(360.0)
    end
  end

  describe "#estimate" do
    it "POSTs to the charge estimator" do
      stub_request(:post, estimate_url)
        .with(body: hash_including("price" => "180", "quantity" => "2"))
        .to_return(status: 200, body: { brokerage: 1.5 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(resource.estimate(params)["brokerage"]).to eq(1.5)
    end

    it "preserves a fractional quantity" do
      stub_request(:post, estimate_url)
        .with(body: hash_including("quantity" => "0.5"))
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      resource.estimate(params.merge(quantity: 0.5))

      expect(WebMock).to have_requested(:post, estimate_url).with(body: hash_including("quantity" => "0.5"))
    end

    it "accepts numeric input given as a string" do
      stub_request(:post, estimate_url)
        .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })

      expect { resource.estimate(params.merge(price: "180", quantity: "2")) }.not_to raise_error
    end
  end

  describe "validation" do
    it "rejects a missing transaction type" do
      expect { resource.calculate(params.except(:transaction_type)) }
        .to raise_error(DhanHQ::ValidationError, /transaction_type/)
    end

    it "rejects a missing security id" do
      expect { resource.calculate(params.except(:security_id)) }
        .to raise_error(DhanHQ::ValidationError, /security_id/)
    end

    it "rejects a non-numeric price" do
      expect { resource.calculate(params.merge(price: "abc")) }
        .to raise_error(DhanHQ::ValidationError, /numeric/)
    end

    it "rejects a zero quantity" do
      expect { resource.calculate(params.merge(quantity: 0)) }
        .to raise_error(DhanHQ::ValidationError, /quantity/)
    end

    it "rejects a negative price" do
      expect { resource.calculate(params.merge(price: -1.0)) }
        .to raise_error(DhanHQ::ValidationError, /price/)
    end
  end
end
