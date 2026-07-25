# frozen_string_literal: true

RSpec.describe DhanHQ::DryRun::Simulator do
  subject(:simulator) { described_class.new(ledger: ledger) }

  let(:ledger) { DhanHQ::DryRun::Ledger.new }

  before do
    DhanHQ.configure do |config|
      config.client_id = "1000000001"
      config.access_token = "test-token"
      config.dry_run = true
    end
  end

  after { DhanHQ.reset_configuration! }

  describe "#simulates?" do
    it "simulates order placement" do
      expect(simulator.simulates?(:post, "/v2/orders")).to be(true)
    end

    it "simulates cancellation and position exits" do
      expect(simulator.simulates?(:delete, "/v2/orders/123")).to be(true)
      expect(simulator.simulates?(:delete, "/v2/positions")).to be(true)
    end

    it "leaves ordinary reads alone" do
      expect(simulator.simulates?(:get, "/v2/orders")).to be(false)
      expect(simulator.simulates?(:get, "/v2/holdings")).to be(false)
    end

    it "leaves read-only POSTs alone" do
      %w[/v2/optionchain /v2/charts/intraday /v2/marketfeed/ltp /v2/margincalculator].each do |path|
        expect(simulator.simulates?(:post, path)).to be(false)
      end
    end

    it "replays a read for an id it invented" do
      expect(simulator.simulates?(:get, "/v2/orders/DRYRUN-ABC123")).to be(true)
    end

    it "does nothing at all when dry run is off" do
      DhanHQ.configuration.dry_run = false

      expect(simulator.simulates?(:post, "/v2/orders")).to be(false)
      expect(simulator.simulates?(:get, "/v2/orders/DRYRUN-ABC123")).to be(false)
    end
  end

  describe "#response_for" do
    it "fabricates an order id for a placement" do
      response = simulator.response_for(:post, "/v2/orders", { securityId: "11536" })

      expect(response["orderId"]).to start_with("DRYRUN-")
      expect(response["orderStatus"]).to eq("TRANSIT")
      expect(response["dryRun"]).to be(true)
    end

    it "records the placement so the models' refetch resolves locally" do
      placed = simulator.response_for(:post, "/v2/orders", { securityId: "11536", quantity: 5 })
      replayed = simulator.response_for(:get, "/v2/orders/#{placed["orderId"]}", {})

      expect(replayed["orderId"]).to eq(placed["orderId"])
      expect(replayed["securityId"]).to eq("11536")
      expect(replayed["quantity"]).to eq(5)
    end

    it "answers a replay for an unknown simulated id rather than falling through" do
      response = simulator.response_for(:get, "/v2/orders/DRYRUN-NOTINLEDGER", {})

      expect(response["orderId"]).to eq("DRYRUN-NOTINLEDGER")
      expect(response["orderStatus"]).to eq("TRANSIT")
    end

    it "returns one result per leg for a basket, keyed by the caller's sequence" do
      payload = { orders: [{ "sequence" => "1" }, { "sequence" => "2" }] }

      response = simulator.response_for(:post, "/v2/alerts/multi/orders", payload)

      expect(response["orders"].map { |leg| leg["sequence"] }).to eq(%w[1 2])
      expect(response["orders"].map { |leg| leg["orderId"] }).to all(start_with("DRYRUN-"))
    end

    it "falls back to positional sequences when a leg omits one" do
      response = simulator.response_for(:post, "/v2/alerts/multi/orders", { orders: [{}, {}] })

      expect(response["orders"].map { |leg| leg["sequence"] }).to eq(%w[1 2])
    end

    it "returns a bare envelope for a non-order write" do
      response = simulator.response_for(:delete, "/v2/positions", {})

      expect(response["dryRun"]).to be(true)
      expect(response["method"]).to eq("DELETE")
      expect(response).not_to have_key("orderId")
    end

    it "logs the suppressed request" do
      allow(DhanHQ.logger).to receive(:warn)

      simulator.response_for(:post, "/v2/orders", { securityId: "11536" })

      expect(DhanHQ.logger).to have_received(:warn).with(/DHAN_DRY_RUN/)
    end

    it "does not log a replayed read" do
      placed = simulator.response_for(:post, "/v2/orders", {})
      allow(DhanHQ.logger).to receive(:warn)

      simulator.response_for(:get, "/v2/orders/#{placed["orderId"]}", {})

      expect(DhanHQ.logger).not_to have_received(:warn)
    end
  end
end
