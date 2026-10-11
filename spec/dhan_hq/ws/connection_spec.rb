# frozen_string_literal: true

require "dhan_hq"

RSpec.describe DhanHQ::WS::Connection do
  # Feed request codes must follow the official Annexure "Feed Request Code"
  # table (dhanhq.co/docs/v2/annexure#feed-request-code). RequestCode 12 is the
  # whole-connection Disconnect Feed frame and must never be used for
  # per-instrument subscribe/unsubscribe payloads.
  describe "feed request codes" do
    it "maps each feed mode to its official annexure subscribe code" do
      expect(described_class::SUB_CODES).to eq(ticker: 15, quote: 17, full: 21)
    end

    it "maps each feed mode to its official annexure unsubscribe code" do
      expect(described_class::UNSUB_CODES).to eq(ticker: 16, quote: 18, full: 22)
    end

    it "never uses the whole-connection disconnect code for per-instrument frames" do
      aggregate_failures do
        expect(described_class::SUB_CODES.values).not_to include(12)
        expect(described_class::UNSUB_CODES.values).not_to include(12)
        expect(DhanHQ::WS::MarketDepth::Client::UNSUBSCRIBE_REQUEST_CODE).not_to eq(12)
      end
    end

    it "subscribes full market depth with 23 and unsubscribes with 25" do
      expect(DhanHQ::WS::MarketDepth::Client::SUBSCRIBE_REQUEST_CODE).to eq(23)
      expect(DhanHQ::WS::MarketDepth::Client::UNSUBSCRIBE_REQUEST_CODE).to eq(25)
    end
  end

  describe "#uniq" do
    subject(:connection) { described_class.new(url: "wss://example.test", mode: :ticker, bus: bus, state: state) }

    let(:bus) { DhanHQ::WS::CmdBus.new }
    let(:state) { DhanHQ::WS::SubState.new }

    it "deduplicates by ExchangeSegment and SecurityId, keeping the first occurrence" do
      list = [
        { ExchangeSegment: "NSE_EQ", SecurityId: 1333, extra: 1 },
        { ExchangeSegment: "NSE_EQ", SecurityId: 1333, extra: 2 },
        { ExchangeSegment: "BSE_EQ", SecurityId: 532_540 }
      ]

      result = connection.send(:uniq, list)

      expect(result).to eq([{ ExchangeSegment: "NSE_EQ", SecurityId: 1333, extra: 1 },
                            { ExchangeSegment: "BSE_EQ", SecurityId: 532_540 }])
    end
  end
end
