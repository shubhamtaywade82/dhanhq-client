# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Trade do
  subject(:trade_model) { described_class }

  before do
    # Make sure ENV credentials (CLIENT_ID, ACCESS_TOKEN) are present
    # so that DhanHQ.configure_with_env sets them up
    DhanHQ.configure_with_env
  end

  describe ".all" do
    let(:from_date) { "2024-12-01" }
    let(:to_date)   { "2024-12-31" }
    let(:page)      { 0 }

    it "fetches trades in the given date range and page", vcr: { cassette_name: "models/trade" } do
      trades = trade_model.all(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      expect(trades).to be_an(Array)
    end

    it "returns valid trade objects when trades exist", vcr: { cassette_name: "models/trade" } do
      trades = trade_model.all(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      if trades.any?
        first_trade = trades.first
        expect(first_trade).to be_a(described_class)
        expect(first_trade.order_id).not_to be_nil
        expect(first_trade.traded_quantity).to be_an(Integer).or be_a(Float)
        expect(first_trade.traded_price).to be_an(Float)
      else
        expect(trades.size).to eq(0)
      end
    end
  end

  describe ".today" do
    it "fetches trades for the current day", vcr: { cassette_name: "models/trade_today" } do
      trades = trade_model.today

      expect(trades).to be_an(Array)
    end
  end

  describe ".find_by_order_id" do
    let(:order_id) { "123456789" }

    it "retrieves trade details for the order", vcr: { cassette_name: "models/trade_find" } do
      trade = trade_model.find_by_order_id(order_id)

      expect(trade).to be_a(described_class).or be_nil
    end
  end

  describe "unit tests" do
    let(:history_resource) { instance_double(DhanHQ::Resources::Statements) }
    let(:tradebook_resource) { instance_double(DhanHQ::Resources::Trades) }

    before do
      described_class.instance_variable_set(:@resource, nil)
      described_class.instance_variable_set(:@tradebook_resource, nil)
      allow(described_class).to receive_messages(resource: history_resource, tradebook_resource: tradebook_resource)
    end

    describe ".history" do
      it "returns models when response is array" do
        allow(history_resource).to receive(:trade_history).and_return([{ "orderId" => "OID1" }])

        trades = described_class.history(from_date: "2024-01-01", to_date: "2024-01-02")
        expect(trades.first).to be_a(described_class)
      end

      it "returns [] for non arrays" do
        allow(history_resource).to receive(:trade_history).and_return("unexpected")

        expect(described_class.history(from_date: "2024-01-01", to_date: "2024-01-02")).to eq([])
      end
    end

    describe ".today" do
      it "maps responses to models" do
        allow(tradebook_resource).to receive(:all).and_return([{ "orderId" => "OID1" }])

        trades = described_class.today
        expect(trades.first.order_id).to eq("OID1")
      end
    end

    describe ".find_by_order_id" do
      it "returns nil when response empty" do
        allow(tradebook_resource).to receive(:find).and_return([])

        expect(described_class.find_by_order_id("OID1")).to be_nil
      end

      it "unwraps array payload" do
        allow(tradebook_resource).to receive(:find).and_return([{ "orderId" => "OID1" }])

        trade = described_class.find_by_order_id("OID1")
        expect(trade.order_id).to eq("OID1")
      end
    end
  end
end
