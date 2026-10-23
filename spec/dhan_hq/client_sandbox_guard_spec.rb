# frozen_string_literal: true

RSpec.describe DhanHQ::Client do
  let(:live_url) { "https://api.dhan.co/v2" }
  let(:sandbox_url) { "https://sandbox.dhan.co/v2" }

  after { DhanHQ.reset_configuration! }

  describe "sandbox capability guard" do
    let(:config) do
      DhanHQ::Configuration.new(client_id: "1000000001", access_token: "test-token", mode: :sandbox)
    end

    it "raises SandboxUnsupportedError when the tier resolves to sandbox for an absent endpoint" do
      client = described_class.new(config: config, api_type: :data_api)

      expect { client.post("/v2/marketfeed/ltp", { "NSE_EQ" => [11_536] }) }
        .to raise_error(DhanHQ::SandboxUnsupportedError, /sandbox/)
    end

    it "raises for super orders on the sandbox order tier" do
      client = described_class.new(config: config, api_type: :order_api)

      expect { client.post("/v2/super/orders", {}) }
        .to raise_error(DhanHQ::SandboxUnsupportedError)
    end

    it "does not raise for endpoints the sandbox implements" do
      client = described_class.new(config: config, api_type: :order_api)

      stub_request(:post, "#{sandbox_url}/orders").to_return(
        status: 200, body: { orderId: "sbx-1", orderStatus: "PENDING" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect(client.post("/v2/orders",
                         { "dhanClientId" => "1000000001", "transactionType" => "BUY",
                           "exchangeSegment" => "NSE_EQ" })).to include(:orderId)
    end

    it "does not interfere when the same paths resolve to production" do
      live_config = DhanHQ::Configuration.new(client_id: "1000000001", access_token: "test-token", mode: :hybrid)
      client = described_class.new(config: live_config, api_type: :data_api)

      stub_request(:post, "#{live_url}/marketfeed/ltp").to_return(
        status: 200, body: { "data" => { "NSE_EQ" => {} } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      expect { client.post("/v2/marketfeed/ltp", { "NSE_EQ" => [11_536] }) }
        .not_to raise_error
    end
  end
end
