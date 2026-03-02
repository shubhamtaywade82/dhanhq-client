# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Decoder do
  # Stub WebsocketPacketParser to return controlled hashes instead of parsing binary
  def stub_parser(parsed_hash)
    parser_double = instance_double(DhanHQ::WS::WebsocketPacketParser, parse: parsed_hash)
    allow(DhanHQ::WS::WebsocketPacketParser).to receive(:new).and_return(parser_double)
  end

  describe ".decode" do
    context "with a ticker packet (feed_response_code=2)" do
      before do
        stub_parser(
          feed_response_code: 2, exchange_segment: 1, security_id: 11536,
          ltp: 1500.0, ltt: 1_700_000_000
        )
      end

      subject(:result) { described_class.decode("dummy") }

      it { expect(result[:kind]).to eq(:ticker) }
      it { expect(result[:ltp]).to be_within(0.01).of(1500.0) }
      it { expect(result[:ts]).to eq(1_700_000_000) }
      it { expect(result[:security_id]).to eq("11536") }
      it { expect(result[:segment]).to eq("NSE_EQ") }
    end

    context "with a quote packet (feed_response_code=4)" do
      before do
        stub_parser(
          feed_response_code: 4, exchange_segment: 1, security_id: 2881,
          ltp: 2800.0, ltt: 1_700_000_001, atp: 2799.5, volume: 100_000,
          total_buy_qty: 500, total_sell_qty: 300,
          day_open: 2750.0, day_high: 2820.0, day_low: 2740.0, day_close: 2780.0
        )
      end

      subject(:result) { described_class.decode("dummy") }

      it { expect(result[:kind]).to eq(:quote) }
      it { expect(result[:ltp]).to be_within(0.01).of(2800.0) }
      it { expect(result[:vol]).to eq(100_000) }
      it { expect(result[:ts_buy_qty]).to eq(500) }
      it { expect(result[:ts_sell_qty]).to eq(300) }
      it { expect(result[:day_high]).to be_within(0.01).of(2820.0) }
    end

    context "with an OI packet (feed_response_code=5)" do
      before do
        stub_parser(
          feed_response_code: 5, exchange_segment: 2, security_id: 999,
          open_interest: 125_000
        )
      end

      it "returns kind :oi with the open_interest value" do
        result = described_class.decode("dummy")
        expect(result[:kind]).to eq(:oi)
        expect(result[:oi]).to eq(125_000)
      end
    end

    context "with a prev_close packet (feed_response_code=6)" do
      before do
        stub_parser(
          feed_response_code: 6, exchange_segment: 1, security_id: 1333,
          prev_close: 2100.0, oi_prev: 80_000
        )
      end

      it "returns kind :prev_close with correct fields" do
        result = described_class.decode("dummy")
        expect(result[:kind]).to eq(:prev_close)
        expect(result[:prev_close]).to be_within(0.01).of(2100.0)
        expect(result[:oi_prev]).to eq(80_000)
      end
    end

    context "with a full packet (feed_response_code=8)" do
      let(:depth_level) do
        double("MarketDepthLevel",
               respond_to?: true,
               bid_price: 1499.5,
               ask_price: 1500.5)
      end

      before do
        allow(depth_level).to receive(:respond_to?).with(:bid_price).and_return(true)
        allow(depth_level).to receive(:respond_to?).with(:ask_price).and_return(true)
        allow(depth_level).to receive(:[]).and_return(nil)

        stub_parser(
          feed_response_code: 8, exchange_segment: 1, security_id: 11536,
          ltp: 1500.0, ltt: 1_700_000_002, atp: 1499.0, volume: 75_000,
          total_buy_qty: 400, total_sell_qty: 200,
          open_interest: 50_000, highest_open_interest: 60_000, lowest_open_interest: 40_000,
          day_open: 1480.0, day_high: 1515.0, day_low: 1470.0, day_close: 1490.0,
          market_depth: [depth_level]
        )
      end

      subject(:result) { described_class.decode("dummy") }

      it { expect(result[:kind]).to eq(:full) }
      it { expect(result[:ltp]).to be_within(0.01).of(1500.0) }
      it { expect(result[:oi]).to eq(50_000) }
      it { expect(result[:oi_high]).to eq(60_000) }
      it { expect(result[:bid]).to be_within(0.01).of(1499.5) }
      it { expect(result[:ask]).to be_within(0.01).of(1500.5) }
    end

    context "with a depth_bid packet (feed_response_code=41)" do
      before do
        stub_parser(
          feed_response_code: 41, exchange_segment: 1, security_id: 2881,
          bid_quantity: 500, ask_quantity: 300,
          no_of_bid_orders: 10, no_of_ask_orders: 8,
          bid_price: 1499.5, ask_price: 1500.25
        )
      end

      it "returns kind :depth_bid with bid/ask fields" do
        result = described_class.decode("dummy")
        expect(result[:kind]).to eq(:depth_bid)
        expect(result[:bid_quantity]).to eq(500)
        expect(result[:bid]).to be_within(0.01).of(1499.5)
      end
    end

    context "with a depth_ask packet (feed_response_code=51)" do
      before do
        stub_parser(
          feed_response_code: 51, exchange_segment: 1, security_id: 2881,
          bid_quantity: 400, ask_quantity: 600,
          no_of_bid_orders: 5, no_of_ask_orders: 7,
          bid_price: 1498.0, ask_price: 1501.0
        )
      end

      it "returns kind :depth_ask" do
        result = described_class.decode("dummy")
        expect(result[:kind]).to eq(:depth_ask)
      end
    end

    context "with a disconnect packet (feed_response_code=50)" do
      before do
        stub_parser(
          feed_response_code: 50, exchange_segment: 1, security_id: 0,
          disconnection_code: 1008
        )
      end

      it "returns nil" do
        expect(described_class.decode("dummy")).to be_nil
      end
    end

    context "with an unknown feed code" do
      before do
        stub_parser(feed_response_code: 99, exchange_segment: 1, security_id: 100)
      end

      it "returns nil" do
        expect(described_class.decode("dummy")).to be_nil
      end
    end

    context "when the parser returns nil" do
      before do
        parser_double = instance_double(DhanHQ::WS::WebsocketPacketParser, parse: nil)
        allow(DhanHQ::WS::WebsocketPacketParser).to receive(:new).and_return(parser_double)
      end

      it "returns nil" do
        expect(described_class.decode("dummy")).to be_nil
      end
    end

    context "when the parser returns an empty hash" do
      before { stub_parser({}) }

      it "returns nil" do
        expect(described_class.decode("dummy")).to be_nil
      end
    end

    context "when a StandardError is raised during decode" do
      before do
        allow(DhanHQ::WS::WebsocketPacketParser).to receive(:new).and_raise(StandardError, "parse boom")
      end

      it "returns nil without raising" do
        expect { described_class.decode("dummy") }.not_to raise_error
        expect(described_class.decode("dummy")).to be_nil
      end
    end
  end
end
