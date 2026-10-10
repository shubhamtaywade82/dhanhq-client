# frozen_string_literal: true

RSpec.describe DhanHQ::WS::Connection do
  # The official Live Market Feed docs define the request codes:
  # subscribe ticker/quote/full = 15/17/21, unsubscribe = code+1 (16/18/22),
  # and 12 is the DISCONNECT frame — never a per-instrument unsubscribe.
  describe "feed request codes" do
    it "maps each feed mode to its own subscribe RequestCode" do
      expect(described_class::SUB_CODES).to eq(ticker: 15, quote: 17, full: 21)
    end

    it "maps each feed mode to subscribe+1 unsubscribe RequestCodes" do
      expect(described_class::UNSUB_CODES).to eq(ticker: 16, quote: 18, full: 22)
    end

    it "never uses the disconnect code (12) for unsubscribes" do
      expect(described_class::UNSUB_CODES.values).not_to include(12)
      expect(described_class::SUB_CODES.values).not_to include(12)
    end
  end

  describe "subscription frames" do
    subject(:connection) do
      described_class.new(url: "wss://api-feed.dhan.co?version=2", mode: :full,
                          bus: DhanHQ::WS::CmdBus.new, state: DhanHQ::WS::SubState.new)
    end

    let(:ws) { instance_double(Faye::WebSocket::Client) }
    let(:sent) { [] }

    before do
      connection.instance_variable_set(:@ws, ws)
      allow(ws).to receive(:send) { |msg| sent << msg }
    end

    it "sends the full-feed RequestCode 21 when subscribing" do
      connection.send(:send_sub, [{ ExchangeSegment: "NSE_EQ", SecurityId: "1333" }])

      payload = JSON.parse(sent.first)
      expect(payload["RequestCode"]).to eq(21)
      expect(payload["InstrumentCount"]).to eq(1)
      expect(payload["InstrumentList"]).to eq([{ "ExchangeSegment" => "NSE_EQ", "SecurityId" => "1333" }])
    end

    it "sends RequestCode 22 (not the disconnect code) when unsubscribing" do
      connection.send(:send_unsub, [{ ExchangeSegment: "NSE_EQ", SecurityId: "1333" }])

      payload = JSON.parse(sent.first)
      expect(payload["RequestCode"]).to eq(22)
      expect(payload["RequestCode"]).not_to eq(12)
    end

    it "batches subscriptions at 100 instruments per message" do
      list = 250.times.map { |i| { ExchangeSegment: "NSE_EQ", SecurityId: i.to_s } }

      connection.send(:send_sub, list)

      expect(sent.size).to eq(3)
      expect(JSON.parse(sent.last)["InstrumentCount"]).to eq(50)
    end
  end
end
