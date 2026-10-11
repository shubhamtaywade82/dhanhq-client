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

  describe "request wire format" do
    subject(:statements_resource) { described_class.new }

    let(:base) { "https://api.dhan.co/v2" }

    before do
      ENV["DHAN_CLIENT_ID"] = "test_client_id"
      ENV["DHAN_ACCESS_TOKEN"] = "test_access_token"
      DhanHQ.configure_with_env
    end

    it "sends from-date and to-date as dashed query params on /v2/ledger" do
      stub_request(:get, "#{base}/ledger?from-date=2025-01-01&to-date=2025-01-31")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      statements_resource.ledger(from_date: "2025-01-01", to_date: "2025-01-31")

      expect(WebMock).to have_requested(:get, "#{base}/ledger?from-date=2025-01-01&to-date=2025-01-31")
    end

    it "returns ledger entries with indifferent access" do
      entry = { narration: "UPI TRANSFER", voucherdate: "2025-01-15", debit: 0.0, credit: 10_000.0, runbal: 57_511.46 }
      stub_request(:get, "#{base}/ledger?from-date=2025-01-01&to-date=2025-01-31")
        .to_return(status: 200, body: [entry].to_json, headers: { "Content-Type" => "application/json" })

      response = statements_resource.ledger(from_date: "2025-01-01", to_date: "2025-01-31")

      expect(response.first["narration"]).to eq("UPI TRANSFER")
      expect(response.first[:runbal]).to eq(57_511.46)
    end

    it "GETs /v2/trades/{from-date}/{to-date}/{page} for trade history" do
      stub_request(:get, "#{base}/trades/2025-01-01/2025-01-31/2")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      statements_resource.trade_history(from_date: "2025-01-01", to_date: "2025-01-31", page: 2)

      expect(WebMock).to have_requested(:get, "#{base}/trades/2025-01-01/2025-01-31/2")
    end

    it "defaults the trade history page to 0" do
      stub_request(:get, "#{base}/trades/2025-01-01/2025-01-31/0")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      statements_resource.trade_history(from_date: "2025-01-01", to_date: "2025-01-31")

      expect(WebMock).to have_requested(:get, "#{base}/trades/2025-01-01/2025-01-31/0")
    end
  end
end
