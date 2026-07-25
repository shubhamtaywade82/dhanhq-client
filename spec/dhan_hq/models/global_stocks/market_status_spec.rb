# frozen_string_literal: true

RSpec.describe DhanHQ::Models::GlobalStocks::MarketStatus do
  let(:url) { "https://api.dhan.co/v2/globalstocks/marketstatus" }

  before do
    DhanHQ.configure_with_env
    described_class.instance_variable_set(:@resource, nil)
  end

  after { described_class.instance_variable_set(:@resource, nil) }

  describe ".fetch" do
    it "reports an open market" do
      stub_request(:get, url)
        .to_return(status: 200,
                   body: { status: "open", marketOpenTime: "09:30", marketCloseTime: "16:00",
                           holidayFlag: false }.to_json,
                   headers: { "Content-Type" => "application/json" })

      status = described_class.fetch

      expect(status).to be_open
      expect(status).not_to be_closed
      expect(status).not_to be_holiday
      expect(status.market_open_time).to eq("09:30")
    end

    it "reports a closed market on a holiday" do
      stub_request(:get, url)
        .to_return(status: 200, body: { status: "closed", holidayFlag: true }.to_json,
                   headers: { "Content-Type" => "application/json" })

      status = described_class.fetch

      expect(status).to be_closed
      expect(status).to be_holiday
    end
  end

  describe ".open?" do
    it "answers directly from the API" do
      stub_request(:get, url)
        .to_return(status: 200, body: { status: "open" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.open?).to be(true)
    end
  end

  describe "#open?" do
    it "matches the status case-insensitively" do
      expect(described_class.new({ status: "OPEN" }, skip_validation: true)).to be_open
    end

    it "treats an unknown status as closed" do
      expect(described_class.new({ status: nil }, skip_validation: true)).to be_closed
    end
  end

  describe "#to_prompt" do
    it "summarizes the session" do
      status = described_class.new({ status: "open", marketOpenTime: "09:30" }, skip_validation: true)

      expect(status.to_prompt).to include("US market open", "09:30")
    end
  end
end
