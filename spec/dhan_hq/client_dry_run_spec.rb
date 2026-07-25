# frozen_string_literal: true

RSpec.describe DhanHQ::Client do
  subject(:client) { described_class.new(api_type: :order_api) }

  let(:order_payload) do
    {
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "INTRADAY",
      orderType: "MARKET",
      validity: "DAY",
      securityId: "11536",
      quantity: 5
    }
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
    allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(nil)
    stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "dry-run mode" do
    before { DhanHQ.configuration.dry_run = true }

    after { DhanHQ.configuration.dry_run = false }

    it "does not send an order placement" do
      response = client.request(:post, "/v2/orders", order_payload)

      expect(response["dryRun"]).to be(true)
      expect(WebMock).not_to have_requested(:post, "https://api.dhan.co/v2/orders")
    end

    it "returns a simulated order id so caller code paths complete" do
      response = client.request(:post, "/v2/orders", order_payload)

      expect(response["orderId"]).to start_with("DRYRUN-")
      expect(response["orderStatus"]).to eq("TRANSIT")
    end

    it "simulates a modification without an order id" do
      response = client.request(:put, "/v2/orders/123", order_payload)

      expect(response["dryRun"]).to be(true)
      expect(response["method"]).to eq("PUT")
      expect(response).not_to have_key("orderId")
    end

    it "simulates a cancellation" do
      response = client.request(:delete, "/v2/orders/123", {})

      expect(response["dryRun"]).to be(true)
      expect(WebMock).not_to have_requested(:delete, "https://api.dhan.co/v2/orders/123")
    end

    it "simulates Global Stocks order placement" do
      response = client.request(:post, "/v2/globalstocks/orders", { securityId: "AAPL" })

      expect(response["orderId"]).to start_with("DRYRUN-")
    end

    it "simulates an exit-all-positions request" do
      response = client.request(:delete, "/v2/positions", {})

      expect(response["dryRun"]).to be(true)
    end

    it "still sends GET reads to the API" do
      stub_request(:get, "https://api.dhan.co/v2/orders")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      client.request(:get, "/v2/orders", {})

      expect(WebMock).to have_requested(:get, "https://api.dhan.co/v2/orders")
    end

    it "still sends read-only POSTs such as the option chain" do
      stub_request(:post, "https://api.dhan.co/v2/optionchain")
        .to_return(status: 200, body: { data: {} }.to_json, headers: { "Content-Type" => "application/json" })

      client.request(:post, "/v2/optionchain", { UnderlyingScrip: 13 })

      expect(WebMock).to have_requested(:post, "https://api.dhan.co/v2/optionchain")
    end

    it "still sends the margin calculator, which does not change state" do
      stub_request(:post, "https://api.dhan.co/v2/margincalculator")
        .to_return(status: 200, body: { totalMargin: 1.0 }.to_json,
                   headers: { "Content-Type" => "application/json" })

      client.request(:post, "/v2/margincalculator", order_payload)

      expect(WebMock).to have_requested(:post, "https://api.dhan.co/v2/margincalculator")
    end

    it "lets the model APIs complete without any live request" do
      order = DhanHQ::Models::Order.place(
        transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "INTRADAY",
        order_type: "MARKET", validity: "DAY", security_id: "11536", quantity: 5
      )

      expect(order).to be_a(DhanHQ::Models::Order)
      expect(order.order_id).to start_with("DRYRUN-")
      expect(order.security_id).to eq("11536")
      expect(WebMock).not_to have_requested(:get, %r{/v2/orders/DRYRUN-})
    end

    it "lets a basket rehearsal return a MultiOrder rather than an error" do
      result = DhanHQ::Models::MultiOrder.place([
                                                  { sequence: "1", transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
                                                    order_type: "LIMIT", validity: "DAY", security_id: "11536", quantity: 1, price: 1500.0 }
                                                ])

      expect(result).to be_a(DhanHQ::Models::MultiOrder)
      expect(result).to be_all_accepted
      expect(result.for_sequence("1").order_id).to start_with("DRYRUN-")
    end

    it "logs the suppressed payload for auditing" do
      allow(DhanHQ.logger).to receive(:warn)

      client.request(:post, "/v2/orders", order_payload)

      expect(DhanHQ.logger).to have_received(:warn).with(/DHAN_DRY_RUN/)
    end
  end

  describe "transient retries on non-idempotent writes" do
    it "does not retry an order placement that timed out" do
      stub_request(:post, "https://api.dhan.co/v2/orders").to_timeout

      expect { client.request(:post, "/v2/orders", order_payload) }
        .to raise_error(DhanHQ::NetworkError)
      expect(WebMock).to have_requested(:post, "https://api.dhan.co/v2/orders").once
    end

    it "does not retry an order placement that hit a 429" do
      stub_request(:post, "https://api.dhan.co/v2/orders")
        .to_return(status: 429, body: { errorCode: "DH-904", errorMessage: "Rate limit" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect { client.request(:post, "/v2/orders", order_payload) }
        .to raise_error(DhanHQ::RateLimitError)
      expect(WebMock).to have_requested(:post, "https://api.dhan.co/v2/orders").once
    end

    it "does retry when the caller opts in" do
      DhanHQ.configuration.retry_non_idempotent_writes = true
      stub_request(:post, "https://api.dhan.co/v2/orders")
        .to_timeout.then
        .to_return(status: 200, body: { orderId: "1", orderStatus: "TRANSIT" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      response = client.request(:post, "/v2/orders", order_payload)

      expect(response["orderId"]).to eq("1")
      expect(WebMock).to have_requested(:post, "https://api.dhan.co/v2/orders").twice
    ensure
      DhanHQ.configuration.retry_non_idempotent_writes = false
    end

    it "still retries idempotent reads" do
      stub_request(:get, "https://api.dhan.co/v2/orders")
        .to_timeout.then
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      client.request(:get, "/v2/orders", {})

      expect(WebMock).to have_requested(:get, "https://api.dhan.co/v2/orders").twice
    end

    it "still retries a read-only POST such as the option chain" do
      stub_request(:post, "https://api.dhan.co/v2/optionchain")
        .to_timeout.then
        .to_return(status: 200, body: { data: {} }.to_json, headers: { "Content-Type" => "application/json" })

      client.request(:post, "/v2/optionchain", { UnderlyingScrip: 13 })

      expect(WebMock).to have_requested(:post, "https://api.dhan.co/v2/optionchain").twice
    end
  end

  describe "auto correlation id" do
    it "is off by default so payloads are unchanged" do
      stub_request(:post, "https://api.dhan.co/v2/orders")
        .to_return(status: 200, body: { orderId: "1" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      client.request(:post, "/v2/orders", order_payload)

      expect(WebMock).to(have_requested(:post, "https://api.dhan.co/v2/orders")
        .with { |req| !JSON.parse(req.body).key?("correlationId") })
    end

    context "when enabled" do
      before { DhanHQ.configuration.auto_correlation_id = true }

      after { DhanHQ.configuration.auto_correlation_id = false }

      it "adds a correlation id to order placements" do
        stub_request(:post, "https://api.dhan.co/v2/orders")
          .to_return(status: 200, body: { orderId: "1" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        client.request(:post, "/v2/orders", order_payload)

        expect(WebMock).to(have_requested(:post, "https://api.dhan.co/v2/orders")
          .with { |req| JSON.parse(req.body)["correlationId"].to_s.start_with?("dhq-") })
      end

      it "preserves an explicit correlation id" do
        stub_request(:post, "https://api.dhan.co/v2/orders")
          .to_return(status: 200, body: { orderId: "1" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        client.request(:post, "/v2/orders", order_payload.merge(correlationId: "mine-123"))

        expect(WebMock).to(have_requested(:post, "https://api.dhan.co/v2/orders")
          .with { |req| JSON.parse(req.body)["correlationId"] == "mine-123" })
      end

      it "generates an id short enough for the API limit" do
        stub_request(:post, "https://api.dhan.co/v2/orders")
          .to_return(status: 200, body: { orderId: "1" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        client.request(:post, "/v2/orders", order_payload)

        expect(WebMock).to(have_requested(:post, "https://api.dhan.co/v2/orders")
          .with { |req| JSON.parse(req.body)["correlationId"].length <= 25 })
      end

      # In normal use BaseAPI camelizes before Client sees the payload, so a caller's
      # id arrives as correlationId and is passed straight through.
      [:correlationId, "correlationId"].each do |key|
        it "preserves an explicit id supplied as #{key.inspect}" do
          stub_request(:post, "https://api.dhan.co/v2/orders")
            .to_return(status: 200, body: { orderId: "1" }.to_json,
                       headers: { "Content-Type" => "application/json" })

          client.request(:post, "/v2/orders", order_payload.merge(key => "mine-123"))

          expect(WebMock).to(have_requested(:post, "https://api.dhan.co/v2/orders")
            .with { |req| JSON.parse(req.body)["correlationId"] == "mine-123" })
        end
      end

      # A snake_case id only reaches here when someone calls Client#request directly,
      # bypassing BaseAPI. The guard still recognises it and declines to generate a
      # second id — but it does not rewrite the caller's key, which would be a
      # surprising mutation of their payload.
      [:correlation_id, "correlation_id"].each do |key|
        it "generates nothing when the caller already passed #{key.inspect}" do
          stub_request(:post, "https://api.dhan.co/v2/orders")
            .to_return(status: 200, body: { orderId: "1" }.to_json,
                       headers: { "Content-Type" => "application/json" })

          client.request(:post, "/v2/orders", order_payload.merge(key => "mine-123"))

          expect(WebMock).to(have_requested(:post, "https://api.dhan.co/v2/orders")
            .with { |req| !JSON.parse(req.body).key?("correlationId") })
        end
      end

      it "does not touch non-order writes" do
        stub_request(:delete, "https://api.dhan.co/v2/orders/123")
          .to_return(status: 200, body: { orderStatus: "CANCELLED" }.to_json,
                     headers: { "Content-Type" => "application/json" })

        client.request(:delete, "/v2/orders/123", {})

        expect(WebMock).to have_requested(:delete, "https://api.dhan.co/v2/orders/123")
      end
    end
  end
end
