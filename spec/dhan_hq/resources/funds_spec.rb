# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Funds do
  let(:funds) { described_class.new }

  let(:mock_margin_response) do
    {
      totalMargin: 10_000.0,
      spanMargin: 4000.0,
      exposureMargin: 2000.0,
      availableBalance: 5000.0,
      variableMargin: 1000.0,
      insufficientBalance: 5000.0,
      brokerage: 50.0,
      leverage: "10x"
    }.to_json
  end

  let(:mock_fund_limit_response) do
    {
      dhanClientId: "1000000009",
      availabelBalance: 98_440.0,
      sodLimit: 113_642.0,
      collateralAmount: 0.0,
      receiveableAmount: 0.0,
      utilizedAmount: 15_202.0,
      blockedPayoutAmount: 0.0,
      withdrawableBalance: 98_310.0
    }.to_json
  end

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "header.payload.signature" # Mock JWT
      config.client_id = "test_client_id"
    end

    stub_request(:post, "https://api.dhan.co/v2/margincalculator")
      .to_return(
        status: 200,
        body: mock_margin_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.dhan.co/v2/fundlimit")
      .to_return(
        status: 200,
        body: mock_fund_limit_response,
        headers: { "Content-Type" => "application/json" }
      )
  end

  after { VCR.turn_on! }

  describe "#margin_calculator" do
    it "calculates margin requirements successfully" do
      params = {
        dhanClientId: "1000000132",
        exchangeSegment: "NSE_EQ",
        transactionType: "BUY",
        quantity: 5,
        productType: "CNC",
        securityId: "1333",
        price: 1428.0,
        triggerPrice: 1427.0
      }

      response = funds.margin_calculator(params)
      expect(response["totalMargin"]).to eq(10_000.0)
      expect(response["spanMargin"]).to eq(4000.0)
      expect(response["exposureMargin"]).to eq(2000.0)
    end
  end

  describe "#fund_limit" do
    it "retrieves the fund limits successfully" do
      response = funds.fund_limit
      expect(response["availabelBalance"]).to eq(98_440.0)
      expect(response["sodLimit"]).to eq(113_642.0)
      expect(response["withdrawableBalance"]).to eq(98_310.0)
    end
  end
end
