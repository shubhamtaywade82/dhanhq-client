# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::MarginCalculator do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/margincalculator" }
  let(:margin_body) do
    {
      marginRequired: 2450.55,
      marginBlockRequired: 0.0,
      spanMargin: 0.0,
      exposureMargin: 0.0,
      optionPremium: 0.0,
      additionalMargin: 0.0
    }
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
  end

  describe "#calculate" do
    it "POSTs camelized params to /v2/margincalculator" do
      stub_request(:post, base)
        .to_return(status: 200, body: margin_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.calculate(
        security_id: "1333", exchange_segment: "NSE_EQ", transaction_type: "BUY",
        ord_type: "LIMIT", product_type: "CNC", quantity: 10, price: 2450.55
      )

      expect(WebMock).to(have_requested(:post, base).with do |req|
        JSON.parse(req.body).values_at("securityId", "exchangeSegment", "transactionType", "ordType", "productType") ==
          %w[1333 NSE_EQ BUY LIMIT CNC]
      end)
    end

    it "injects dhanClientId into the body" do
      stub_request(:post, base)
        .to_return(status: 200, body: margin_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.calculate(security_id: "1333", exchange_segment: "NSE_EQ", transaction_type: "BUY", quantity: 10)

      expect(WebMock).to(have_requested(:post, base).with do |req|
        JSON.parse(req.body)["dhanClientId"] == "test_client_id"
      end)
    end

    it "returns margin details with indifferent access" do
      stub_request(:post, base)
        .to_return(status: 200, body: margin_body.to_json, headers: { "Content-Type" => "application/json" })

      response = resource.calculate(security_id: "1333", exchange_segment: "NSE_EQ", transaction_type: "BUY", quantity: 10)

      expect(response["marginRequired"]).to eq(2450.55)
      expect(response[:spanMargin]).to eq(0.0)
    end

    it "raises InputExceptionError on 400" do
      stub_request(:post, base).to_return(
        status: 400,
        body: { errorCode: "DH-905", errorMessage: "Input exception" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect do
        resource.calculate(security_id: "1333", exchange_segment: "NSE_EQ", transaction_type: "BUY", quantity: 10)
      end.to raise_error(DhanHQ::InputExceptionError)
    end
  end

  describe "#calculate_multi" do
    let(:multi_body) do
      {
        marginRequired: 4901.10,
        hedgeBenefit: 850.25,
        scripMargin: [{ securityId: "1333", marginRequired: 2450.55 }]
      }
    end

    it "deep-camelizes the nested scripList entries so the API receives camelCase keys" do
      stub_request(:post, "#{base}/multi")
        .to_return(status: 200, body: multi_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.calculate_multi(
        scrip_list: [{ security_id: "1333", exchange_segment: "NSE_EQ", transaction_type: "BUY",
                       product_type: "CNC", quantity: 10, price: 2450.55, position_type: "LONG" }],
        include_position: false, include_order: false
      )

      expect(WebMock).to(have_requested(:post, "#{base}/multi").with do |req|
        scrip = JSON.parse(req.body)["scripList"].first
        scrip.key?("securityId") && scrip.keys.none? { |k| k.include?("_") }
      end)
    end

    it "returns combined margin details with indifferent access" do
      stub_request(:post, "#{base}/multi")
        .to_return(status: 200, body: multi_body.to_json, headers: { "Content-Type" => "application/json" })

      response = resource.calculate_multi(scrip_list: [], include_position: false, include_order: false)

      expect(response[:hedgeBenefit]).to eq(850.25)
      expect(response["marginRequired"]).to eq(4901.10)
    end
  end
end
