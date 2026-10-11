# frozen_string_literal: true

RSpec.describe DhanHQ::WS::MarketDepth::Client do
  let(:config) do
    DhanHQ::Configuration.new(client_id: "1000000001", access_token: "tok", market_depth_level: level)
  end
  let(:level) { 20 }
  let(:client) { described_class.new(config: config) }
  let(:sent) { [] }

  def side_packet(code:, security_id:, rows:)
    body = rows.map { |price, qty, orders| [price, qty, orders].pack("EL<L<") }.join
    body += "\x00".b * ((20 - rows.size) * 16)
    [12 + body.bytesize, code, 1, security_id, 0].pack("s<CCl<L<") + body
  end

  before do
    allow(client).to receive(:send_message) { |msg| sent << msg }
  end

  it "merges separately delivered bid and ask packets into one book update" do
    updates = []
    client.on(:depth_update) { |u| updates << u }

    frame = side_packet(code: 41, security_id: 1333, rows: [[99.5, 10, 1]]) +
            side_packet(code: 51, security_id: 1333, rows: [[100.5, 20, 2]])
    client.send(:process_message, frame)

    expect(updates.size).to eq(1)
    expect(updates.first).to include(exchange_segment: "NSE_EQ", security_id: "1333", best_bid: 99.5,
                                     best_ask: 100.5, spread: 1.0, total_bid_qty: 10, total_ask_qty: 20)
  end

  describe "subscription messages" do
    let(:instrument) { { exchange_segment: "NSE_EQ", security_id: "1333", symbol: "HDFCBANK" } }

    it "sends a 20-level subscription as an instrument list" do
      client.subscribe(instrument)

      expect(sent.first).to eq("RequestCode" => 23, "InstrumentCount" => 1,
                               "InstrumentList" => [{ "ExchangeSegment" => "NSE_EQ", "SecurityId" => "1333" }])
    end

    # 24 = subscribe + 1, as sent by the official DhanHQ-py SDK (fulldepth.py).
    it "unsubscribes with request code 24" do
      client.subscribe(instrument)
      client.unsubscribe(instrument)

      expect(sent.last["RequestCode"]).to eq(24)
    end

    context "with 200-level depth" do
      let(:level) { 200 }

      it "sends a flat subscription and refuses a second instrument on the connection" do
        client.subscribe(instrument)
        client.subscribe(instrument.merge(security_id: "11536", symbol: "NIFTY"))

        expect(sent).to eq([{ "RequestCode" => 23, "ExchangeSegment" => "NSE_EQ", "SecurityId" => "1333" }])
      end
    end
  end
end
