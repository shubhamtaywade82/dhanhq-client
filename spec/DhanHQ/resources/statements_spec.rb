# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Statements do
  subject(:statements_resource) { described_class.new }

  before do
    # Ensure ENV credentials (DHAN_CLIENT_ID, DHAN_ACCESS_TOKEN) are loaded
    DhanHQ.configure_with_env
  end

  describe "#ledger" do
    it "fetches ledger entries for a given date range", vcr: { cassette_name: "resources/statements" } do
      from_date = "2023-01-01"
      to_date   = "2023-01-31"

      response = statements_resource.ledger(
        from_date: from_date,
        to_date: to_date
      )

      expect(response).to be_an(Array)
    end

    it "returns valid ledger entries when data exists", vcr: { cassette_name: "resources/statements" } do
      from_date = "2023-01-01"
      to_date   = "2023-01-31"

      response = statements_resource.ledger(
        from_date: from_date,
        to_date: to_date
      )

      if response.any?
        entry = response.first
        expect(entry).to be_a(Hash)
        expect(entry).to include("narration", "voucherdate", "debit", "credit", "runbal")
      else
        expect(response.size).to eq(0)
      end
    end
  end

  describe "#trade_history" do
    it "fetches trade history for the given date range and page", vcr: { cassette_name: "resources/statements" } do
      from_date = "2023-01-01"
      to_date   = "2023-01-31"
      page      = 0

      response = statements_resource.trade_history(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      expect(response).to be_an(Array)
    end

    it "returns valid trade entries when data exists", vcr: { cassette_name: "resources/statements" } do
      from_date = "2023-01-01"
      to_date   = "2023-01-31"
      page      = 0

      response = statements_resource.trade_history(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      if response.any?
        trade = response.first
        expect(trade).to be_a(Hash)
        expect(trade).to include("orderId", "exchangeOrderId", "tradedQuantity", "tradedPrice")
      else
        expect(response.size).to eq(0)
      end
    end
  end
end
