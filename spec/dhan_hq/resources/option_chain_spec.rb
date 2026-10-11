# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::OptionChain do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/optionchain" }
  let(:chain_body) do
    {
      data: {
        last_price: 23_105.35,
        expiry: "2025-01-30",
        "23100.000000" => { ce: { last_price: 55.4, oi: 12_345 }, pe: { last_price: 49.85, oi: 11_111 } }
      },
      status: "success"
    }
  end

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
    # The option-chain tier allows 1 req/3s; stub its throttle so the suite never sleeps.
    allow(DhanHQ::RateLimiter.for(:option_chain)).to receive(:throttle!)
  end

  describe "#fetch" do
    it "POSTs titleized params in the body to /v2/optionchain" do
      stub_request(:post, base)
        .to_return(status: 200, body: chain_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.fetch(underlying_scrip: 13, underlying_seg: "IDX_I", expiry: "2025-01-30")

      expect(WebMock).to(have_requested(:post, base).with do |req|
        JSON.parse(req.body).values_at("UnderlyingScrip", "UnderlyingSeg", "Expiry") == [13, "IDX_I", "2025-01-30"]
      end)
    end

    it "injects dhanClientId and sends the client-id header" do
      stub_request(:post, base)
        .to_return(status: 200, body: chain_body.to_json, headers: { "Content-Type" => "application/json" })

      resource.fetch(underlying_scrip: 13, underlying_seg: "IDX_I")

      expect(WebMock).to(have_requested(:post, base).with do |req|
        JSON.parse(req.body)["dhanClientId"] == "test_client_id"
      end)
      expect(WebMock).to have_requested(:post, base)
        .with(headers: { "client-id" => "test_client_id" })
    end

    it "returns chain data with indifferent access" do
      stub_request(:post, base)
        .to_return(status: 200, body: chain_body.to_json, headers: { "Content-Type" => "application/json" })

      response = resource.fetch(underlying_scrip: 13, underlying_seg: "IDX_I")

      expect(response[:data][:last_price]).to eq(23_105.35)
      expect(response["data"]["23100.000000"]["ce"]["oi"]).to eq(12_345)
    end

    it "raises InvalidAuthenticationError on 401" do
      stub_request(:post, base).to_return(
        status: 401,
        body: { errorCode: "TT-401", errorMessage: "Token is invalid or expired." }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { resource.fetch(underlying_scrip: 13, underlying_seg: "IDX_I") }
        .to raise_error(DhanHQ::InvalidAuthenticationError)
    end
  end

  describe "#expirylist" do
    it "POSTs titleized params to /v2/optionchain/expirylist" do
      stub_request(:post, "#{base}/expirylist")
        .to_return(status: 200, body: { data: %w[2025-01-30 2025-02-27], status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.expirylist(underlying_scrip: 13, underlying_seg: "IDX_I")

      expect(WebMock).to(have_requested(:post, "#{base}/expirylist").with do |req|
        JSON.parse(req.body).key?("UnderlyingScrip")
      end)
    end

    it "returns the expiry list with indifferent access" do
      stub_request(:post, "#{base}/expirylist")
        .to_return(status: 200, body: { data: %w[2025-01-30 2025-02-27], status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.expirylist(underlying_scrip: 13, underlying_seg: "IDX_I")

      expect(response[:data]).to eq(%w[2025-01-30 2025-02-27])
    end
  end
end
