# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Trade, vcr: {
  cassette_name: "models/trade", # Name your cassette file
  record: :once
} do
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

    it "fetches trades in the given date range and page" do
      trades = trade_model.all(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      expect(trades).to be_an(Array)

      if trades.any?
        first_trade = trades.first
        expect(first_trade).to be_a(described_class)

        # Basic checks — adjust these keys to match your actual environment
        expect(first_trade.order_id).not_to be_nil
        expect(first_trade.traded_quantity).to be_an(Integer).or be_a(Float)
        expect(first_trade.traded_price).to be_an(Float)
      else
        # It's possible the user had zero trades in that period.
        # So we can just check that it returned an empty array.
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
end
