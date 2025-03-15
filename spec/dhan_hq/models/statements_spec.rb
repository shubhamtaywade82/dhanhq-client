# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Statements, vcr: {
  cassette_name: "resources/statements", # Name your cassette file
  record: :new_episodes
} do
  subject(:statements_resource) { described_class.new }

  before do
    # Ensure ENV credentials (CLIENT_ID, ACCESS_TOKEN) are loaded
    DhanHQ.configure_with_env
  end

  describe "#ledger" do
    it "fetches ledger entries for a given date range" do
      from_date = "2023-01-01"
      to_date   = "2023-01-31"

      response = statements_resource.ledger(
        from_date: from_date,
        to_date: to_date
      )

      expect(response).to be_an(Array)

      if response.any?
        entry = response.first
        # Each entry is a Hash of ledger info like narration, debit, credit, etc.
        expect(entry).to be_a(Hash)
        expect(entry).to include(
          "narration",
          "voucherdate",
          "debit",
          "credit",
          "runbal"
        )
        # Adjust the keys as per your actual API fields
      else
        # If no ledger entries exist for the date range,
        # the array may be empty, which is still valid
        expect(response.size).to eq(0)
      end
    end
  end

  describe "#trade_history" do
    it "fetches trade history for the given date range and page" do
      from_date = "2023-01-01"
      to_date   = "2023-01-31"
      page      = 0

      response = statements_resource.trade_history(
        from_date: from_date,
        to_date: to_date,
        page: page
      )

      expect(response).to be_an(Array)

      if response.any?
        trade = response.first
        # Each trade is a Hash with fields like orderId, tradedPrice, etc.
        expect(trade).to be_a(Hash)
        expect(trade).to include(
          "orderId",
          "exchangeOrderId",
          "tradedQuantity",
          "tradedPrice"
        )
        # Adjust the keys to match your actual response fields
      else
        # If the user had no trades in that period, we might see an empty array
        expect(response.size).to eq(0)
      end
    end
  end
end
