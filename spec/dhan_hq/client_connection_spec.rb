# frozen_string_literal: true

RSpec.describe DhanHQ::Client do
  before { DhanHQ.configure_with_env }

  describe "#initialize" do
    it "opens no connection, so constructing a client does no network setup" do
      client = described_class.new(api_type: :order_api)

      expect(client.instance_variable_get(:@connection)).to be_nil
    end

    it "still checks its one invariant up front" do
      allow(DhanHQ::RateLimiter).to receive(:for).and_return(nil)

      expect { described_class.new(api_type: :order_api) }
        .to raise_error(DhanHQ::Error, /RateLimiter initialization failed/)
    end
  end

  describe "#connection" do
    subject(:client) { described_class.new(api_type: :order_api) }

    it "builds on first use" do
      expect(client.connection).to be_a(Faraday::Connection)
    end

    it "returns the same connection while the base URL is unchanged" do
      first = client.connection

      expect(client.connection).to be(first)
    end

    it "points at the configured base URL" do
      expect(client.connection.url_prefix.to_s).to start_with(DhanHQ.configuration.base_url)
    end

    it "rebuilds when the base URL changes, so a sandbox toggle takes effect" do
      original = client.connection
      DhanHQ.configuration.base_url = "https://sandbox.dhan.co/v2"

      rebuilt = client.connection

      expect(rebuilt).not_to be(original)
      expect(rebuilt.url_prefix.to_s).to start_with("https://sandbox.dhan.co")
    ensure
      DhanHQ.configuration.base_url = nil
    end
  end

  describe "retry exhaustion" do
    subject(:client) { described_class.new(api_type: :order_api) }

    # Minimal payload that satisfies the vendored placeorder contract — these
    # specs exercise retry semantics, but with contract-first validation on by
    # default the wire payload must also be schema-valid.
    let(:contract_valid_order) do
      { transactionType: "BUY", exchangeSegment: "NSE_EQ", securityId: "1333",
        quantity: 1, productType: "CNC", orderType: "LIMIT", validity: "DAY",
        price: 100.0 }
    end

    it "translates a Faraday transport error so rescue DhanHQ::Error catches it" do
      stub_request(:get, "https://api.dhan.co/v2/orders").to_timeout

      expect { client.request(:get, "/v2/orders", {}) }
        .to raise_error(DhanHQ::NetworkError, /after 3 retries/)
    end

    it "omits the retry count when retries were disabled" do
      stub_request(:post, "https://api.dhan.co/v2/orders").to_timeout

      expect { client.request(:post, "/v2/orders", contract_valid_order) }
        .to raise_error(DhanHQ::NetworkError, /\ARequest failed: /)
    end

    it "re-raises this gem's own errors unchanged rather than wrapping them" do
      stub_request(:post, "https://api.dhan.co/v2/orders")
        .to_return(status: 429, body: { errorCode: "DH-904", errorMessage: "Rate limit" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { client.request(:post, "/v2/orders", contract_valid_order) }
        .to raise_error(DhanHQ::RateLimitError)
    end

    it "retries a read before giving up" do
      stub_request(:get, "https://api.dhan.co/v2/orders")
        .to_timeout.then
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      client.request(:get, "/v2/orders", {})

      expect(WebMock).to have_requested(:get, "https://api.dhan.co/v2/orders").twice
    end
  end
end
