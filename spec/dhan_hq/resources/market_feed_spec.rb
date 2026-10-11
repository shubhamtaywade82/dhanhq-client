# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::MarketFeed do
  subject(:resource) { described_class.new }

  let(:base) { "https://api.dhan.co/v2/marketfeed" }

  before do
    ENV["DHAN_CLIENT_ID"] = "test_client_id"
    ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
    DhanHQ.configure_with_env
    # The quote tier allows 1 req/s; stub its throttle so the suite never sleeps.
    allow(DhanHQ::RateLimiter.for(:quote_api)).to receive(:throttle!)
  end

  describe "#ltp" do
    it "POSTs the instrument map unchanged to /v2/marketfeed/ltp" do
      stub_request(:post, "#{base}/ltp")
        .to_return(status: 200, body: { data: { "11536" => { last_price: 2455.75 } }, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.ltp("NSE_EQ" => [11_536])

      expect(WebMock).to(have_requested(:post, "#{base}/ltp").with do |req|
        JSON.parse(req.body).slice("NSE_EQ") == { "NSE_EQ" => [11_536] }
      end)
    end

    it "sends the client-id header" do
      stub_request(:post, "#{base}/ltp")
        .to_return(status: 200, body: { data: {}, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.ltp("NSE_EQ" => [11_536])

      expect(WebMock).to have_requested(:post, "#{base}/ltp")
        .with(headers: { "client-id" => "test_client_id" })
    end

    it "returns LTP data with indifferent access" do
      stub_request(:post, "#{base}/ltp")
        .to_return(status: 200, body: { data: { "11536" => { last_price: 2455.75 } }, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.ltp("NSE_EQ" => [11_536])

      expect(response["data"]["11536"]["last_price"]).to eq(2455.75)
      expect(response[:status]).to eq("success")
    end

    it "raises TooManyRequests-mapped RateLimitError when the data API reports 805" do
      stub_request(:post, "#{base}/ltp").to_return(
        status: 429,
        body: { errorCode: 805, errorMessage: "Too many requests" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      allow(resource.client).to receive(:sleep) # skip retry backoff on the 429 retry loop

      expect { resource.ltp("NSE_EQ" => [11_536]) }.to raise_error(DhanHQ::RateLimitError)
    end
  end

  describe "#ohlc" do
    it "POSTs the instrument map unchanged to /v2/marketfeed/ohlc" do
      stub_request(:post, "#{base}/ohlc")
        .to_return(status: 200, body: { data: { "11536" => { open: 2450.1, close: 2455.75 } }, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.ohlc("NSE_EQ" => [11_536])

      expect(WebMock).to(have_requested(:post, "#{base}/ohlc").with do |req|
        JSON.parse(req.body).slice("NSE_EQ") == { "NSE_EQ" => [11_536] }
      end)
    end

    it "returns OHLC data with indifferent access" do
      stub_request(:post, "#{base}/ohlc")
        .to_return(status: 200, body: { data: { "11536" => { open: 2450.1, close: 2455.75 } }, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.ohlc("NSE_EQ" => [11_536])

      expect(response[:data]["11536"][:open]).to eq(2450.1)
    end
  end

  describe "#quote" do
    it "POSTs the instrument map unchanged to /v2/marketfeed/quote" do
      stub_request(:post, "#{base}/quote")
        .to_return(status: 200, body: { data: { "11536" => { last_price: 2455.75, depth: {} } }, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.quote("NSE_EQ" => [11_536])

      expect(WebMock).to(have_requested(:post, "#{base}/quote").with do |req|
        JSON.parse(req.body).slice("NSE_EQ") == { "NSE_EQ" => [11_536] }
      end)
    end

    it "sends the client-id header on the quote endpoint" do
      stub_request(:post, "#{base}/quote")
        .to_return(status: 200, body: { data: {}, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      resource.quote("NSE_EQ" => [11_536])

      expect(WebMock).to have_requested(:post, "#{base}/quote")
        .with(headers: { "client-id" => "test_client_id" })
    end

    it "returns quote data with indifferent access" do
      stub_request(:post, "#{base}/quote")
        .to_return(status: 200, body: { data: { "11536" => { last_price: 2455.75 } }, status: "success" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = resource.quote("NSE_EQ" => [11_536])

      expect(response["data"]["11536"]["last_price"]).to eq(2455.75)
    end
  end
end
