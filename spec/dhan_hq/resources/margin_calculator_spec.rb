# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Resources::MarginCalculator do
  subject(:resource) { described_class.new }

  let(:base_url) { "https://api.dhan.co/v2/margincalculator" }
  let(:margin_response) do
    { "totalMargin" => 15_000.0, "spanMargin" => 10_000.0, "exposureMargin" => 5_000.0 }
  end

  let(:calc_params) do
    {
      dhan_client_id: "test_client",
      exchange_segment: "NSE_EQ",
      transaction_type: "BUY",
      quantity: 10,
      product_type: "CNC",
      security_id: "1333",
      price: 1500.0
    }
  end

  before do
    DhanHQ.configure do |c|
      c.client_id = "test_client"
      c.access_token = "test_token"
    end
  end

  describe "#calculate" do
    before do
      stub_request(:post, base_url)
        .to_return(status: 200, body: margin_response.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash with margin details" do
      result = resource.calculate(calc_params)
      expect(result).to be_a(Hash)
    end

    it "includes totalMargin" do
      result = resource.calculate(calc_params)
      expect(result).to have_key("totalMargin")
    end
  end

  describe "#calculate_multi" do
    let(:multi_response) { { "totalMargin" => 30_000.0, "hedgeBenefit" => 5_000.0 } }

    before do
      stub_request(:post, "#{base_url}/multi")
        .to_return(status: 200, body: multi_response.to_json,
                   headers: { "Content-Type" => "application/json" })
    end

    it "returns a hash for multi-script margin" do
      result = resource.calculate_multi({ scrip_list: [calc_params] })
      expect(result).to be_a(Hash)
    end
  end
end
