# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::WebsocketPacketParser do
  # Build an 8-byte header (big-endian except security_id which is little-endian int32)
  def build_header(code:, length:, segment:, security_id:)
    [code].pack("C") +      # feed_response_code (uint8)
      [length].pack("n") +  # message_length (uint16 big-endian)
      [segment].pack("C") + # exchange_segment (uint8)
      [security_id].pack("l<") # security_id (int32 little-endian)
  end

  def build_ticker_payload(ltp:, ltt:)
    [ltp].pack("e") + [ltt].pack("l<")
  end

  def build_quote_payload
    [1500.0, 10, 1_700_000_000, 1499.5, 50_000, 200, 300,
     1480.0, 1490.0, 1510.0, 1470.0].pack("e S< L< e L< l< l< e e e e")
  end

  def build_oi_payload(oi:)
    [oi].pack("l<")
  end

  def build_prev_close_payload(prev_close:, oi_prev:)
    [prev_close].pack("e") + [oi_prev].pack("l<")
  end

  def build_depth_payload(bid_qty:, ask_qty:, no_bid:, no_ask:, bid_price:, ask_price:)
    [bid_qty].pack("L<") + [ask_qty].pack("L<") +
      [no_bid].pack("S<") + [no_ask].pack("S<") +
      [bid_price].pack("e") + [ask_price].pack("e")
  end

  def build_disconnect_payload(code:)
    [code].pack("s>")
  end

  describe "#parse" do
    context "with a ticker packet (code=2)" do
      let(:binary) do
        build_header(code: 2, length: 16, segment: 1, security_id: 11536) +
          build_ticker_payload(ltp: 1500.0, ltt: 1_700_000_000)
      end

      subject(:result) { described_class.new(binary).parse }

      it "returns feed_response_code 2" do
        expect(result[:feed_response_code]).to eq(2)
      end

      it "returns the exchange_segment byte" do
        expect(result[:exchange_segment]).to eq(1)
      end

      it "returns the security_id" do
        expect(result[:security_id]).to eq(11536)
      end

      it "returns ltp" do
        expect(result[:ltp]).to be_within(0.01).of(1500.0)
      end

      it "returns ltt" do
        expect(result[:ltt]).to eq(1_700_000_000)
      end
    end

    context "with a quote packet (code=4)" do
      let(:binary) do
        build_header(code: 4, length: 52, segment: 1, security_id: 2881) +
          build_quote_payload
      end

      subject(:result) { described_class.new(binary).parse }

      it "returns feed_response_code 4" do
        expect(result[:feed_response_code]).to eq(4)
      end

      it "returns ltp" do
        expect(result[:ltp]).to be_within(0.01).of(1500.0)
      end

      it "returns volume" do
        expect(result[:volume]).to eq(50_000)
      end
    end

    context "with an OI packet (code=5)" do
      let(:binary) do
        build_header(code: 5, length: 12, segment: 2, security_id: 999) +
          build_oi_payload(oi: 125_000)
      end

      it "returns open_interest" do
        result = described_class.new(binary).parse
        expect(result[:open_interest]).to eq(125_000)
      end
    end

    context "with a prev_close packet (code=6)" do
      let(:binary) do
        build_header(code: 6, length: 16, segment: 1, security_id: 1333) +
          build_prev_close_payload(prev_close: 2100.0, oi_prev: 80_000)
      end

      it "returns prev_close and oi_prev" do
        result = described_class.new(binary).parse
        expect(result[:prev_close]).to be_within(0.01).of(2100.0)
        expect(result[:oi_prev]).to eq(80_000)
      end
    end

    context "with a depth_bid packet (code=41)" do
      let(:binary) do
        build_header(code: 41, length: 28, segment: 1, security_id: 2881) +
          build_depth_payload(bid_qty: 500, ask_qty: 300, no_bid: 10, no_ask: 8,
                              bid_price: 1499.5, ask_price: 1500.25)
      end

      subject(:result) { described_class.new(binary).parse }

      it "returns depth_side :bid" do
        expect(result[:depth_side]).to eq(:bid)
      end

      it "returns bid_quantity" do
        expect(result[:bid_quantity]).to eq(500)
      end

      it "returns bid_price" do
        expect(result[:bid_price]).to be_within(0.01).of(1499.5)
      end
    end

    context "with a depth_ask packet (code=51)" do
      let(:binary) do
        build_header(code: 51, length: 28, segment: 1, security_id: 2881) +
          build_depth_payload(bid_qty: 400, ask_qty: 600, no_bid: 5, no_ask: 7,
                              bid_price: 1498.0, ask_price: 1501.0)
      end

      it "returns depth_side :ask" do
        result = described_class.new(binary).parse
        expect(result[:depth_side]).to eq(:ask)
      end
    end

    context "with a disconnect packet (code=50)" do
      let(:binary) do
        build_header(code: 50, length: 10, segment: 0, security_id: 0) +
          build_disconnect_payload(code: 1008)
      end

      it "returns disconnection_code" do
        result = described_class.new(binary).parse
        expect(result[:disconnection_code]).to eq(1008)
      end
    end

    context "with an unknown feed code" do
      let(:binary) do
        build_header(code: 99, length: 8, segment: 1, security_id: 100) + "\x00" * 4
      end

      it "returns the header fields with an empty body" do
        result = described_class.new(binary).parse
        expect(result[:feed_response_code]).to eq(99)
        expect(result).not_to have_key(:ltp)
      end
    end

    context "when binary data is malformed (too short to parse 8-byte header)" do
      # The constructor eagerly calls Packets::Header.read, which raises EOFError
      # from BinData before #parse is ever reached.  The rescue in #parse does NOT
      # protect against construction-time errors; callers must guard new() itself.
      it "raises an error when the binary is shorter than the 8-byte header" do
        expect { described_class.new("bad".b) }.to raise_error(StandardError)
      end
    end
  end
end
