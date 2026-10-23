# frozen_string_literal: true

# Each example decodes one frame and asserts every decoded field, so the
# example-length and expectation-count cops are disabled for this file.
# rubocop:disable RSpec/ExampleLength, RSpec/MultipleExpectations

require "dhan_hq"

RSpec.describe DhanHQ::WS::Decoder do
  # Binary helpers mirroring the official Live Market Feed v2 wire format
  # (all fields little-endian). Test values use dyadic fractions (.0/.25/.5/.75)
  # so float32 round-trips are exact.
  def header(code, length, segment, security_id)
    [code, length, segment].pack("CvC") + [security_id].pack("l<")
  end

  describe "ticker packet (response code 2)" do
    it "decodes LTP and LTT" do
      binary = header(2, 16, 1, 1333) + [225.5].pack("e") + [1_700_000_000].pack("V")

      tick = described_class.decode(binary)

      expect(tick[:kind]).to eq(:ticker)
      expect(tick[:segment]).to eq("NSE_EQ")
      expect(tick[:security_id]).to eq("1333")
      expect(tick[:ltp]).to eq(225.5)
      expect(tick[:ts]).to eq(1_700_000_000)
    end
  end

  describe "index packet (response code 1)" do
    it "decodes index OHLC and update time instead of dropping the frame" do
      binary = header(1, 32, 0, 13) +
               [19_875.5, 19_700.25, 19_650.0, 19_950.75, 19_680.5].pack("e*") +
               [1_700_000_100].pack("V")

      tick = described_class.decode(binary)

      expect(tick[:kind]).to eq(:index)
      expect(tick[:segment]).to eq("IDX_I")
      expect(tick[:security_id]).to eq("13")
      expect(tick[:ltp]).to eq(19_875.5)
      expect(tick[:latest]).to eq(19_875.5)
      expect(tick[:day_open]).to eq(19_700.25)
      expect(tick[:day_high]).to eq(19_950.75)
      expect(tick[:day_low]).to eq(19_680.5)
      expect(tick[:day_close]).to eq(19_650.0)
      expect(tick[:ts]).to eq(1_700_000_100)
    end
  end

  describe "quote packet (response code 4)" do
    it "decodes all quote components (50-byte frame)" do
      binary = header(4, 50, 2, 49_081) +
               [212.25].pack("e") + [150].pack("v") + [1_700_000_050].pack("V") +
               [212.0].pack("e") + [1_250_000, 300_000, 450_000].pack("V3") +
               [210.5, 213.75, 214.25, 209.5].pack("e*")

      tick = described_class.decode(binary)

      expect(tick[:kind]).to eq(:quote)
      expect(tick[:segment]).to eq("NSE_FNO")
      expect(tick[:ltp]).to eq(212.25)
      expect(tick[:ts]).to eq(1_700_000_050)
      expect(tick[:atp]).to eq(212.0)
      expect(tick[:vol]).to eq(1_250_000)
      expect(tick[:ts_sell_qty]).to eq(300_000)
      expect(tick[:ts_buy_qty]).to eq(450_000)
      expect(tick[:day_open]).to eq(210.5)
      expect(tick[:day_close]).to eq(213.75)
      expect(tick[:day_high]).to eq(214.25)
      expect(tick[:day_low]).to eq(209.5)
    end
  end

  describe "full packet (response code 8)" do
    it "decodes the 162-byte frame including OI and 5-level depth" do
      level = [1000, 900, 3, 4, 211.5, 212.0].pack("VVvvee")
      levels = Array.new(5) { level }.join
      binary = header(8, 162, 2, 49_082) +
               [212.25].pack("e") + [150].pack("v") + [1_700_000_050].pack("V") +
               [212.0].pack("e") + [1_250_000, 300_000, 450_000].pack("V3") +
               [800_000, 900_000, 700_000].pack("V3") +
               [210.5, 213.75, 214.25, 209.5].pack("e*") + levels

      tick = described_class.decode(binary)

      expect(tick[:kind]).to eq(:full)
      expect(tick[:segment]).to eq("NSE_FNO")
      expect(tick[:oi]).to eq(800_000)
      expect(tick[:oi_high]).to eq(900_000)
      expect(tick[:oi_low]).to eq(700_000)
      expect(tick[:day_open]).to eq(210.5)
      expect(tick[:day_close]).to eq(213.75)
      expect(tick[:bid]).to eq(211.5)
      expect(tick[:ask]).to eq(212.0)
      expect(tick[:bid_qty]).to eq(1000)
      expect(tick[:ask_qty]).to eq(900)
    end
  end

  describe "market status packet (response code 7)" do
    it "emits a market_status event for the header-only frame" do
      binary = header(7, 8, 1, 1333)

      tick = described_class.decode(binary)

      expect(tick[:kind]).to eq(:market_status)
      expect(tick[:segment]).to eq("NSE_EQ")
      expect(tick[:security_id]).to eq("1333")
    end
  end

  describe "prev close packet (response code 6)" do
    it "decodes float32 prev close per the v2 spec" do
      binary = header(6, 16, 1, 1333) + [221.5].pack("e") + [500_000].pack("V")

      tick = described_class.decode(binary)

      expect(tick[:kind]).to eq(:prev_close)
      expect(tick[:prev_close]).to eq(221.5)
      expect(tick[:oi_prev]).to eq(500_000)
    end
  end

  describe "disconnect packet (response code 50)" do
    it "reads the uint16 little-endian disconnect code without raising" do
      binary = header(50, 10, 1, 1333) + [805].pack("v")

      expect(described_class.decode(binary)).to be_nil # disconnect is logged, not emitted
    end
  end

  describe "header endianness" do
    it "parses message_length as little-endian" do
      binary = header(2, 16, 1, 1333) + [225.5].pack("e") + [1_700_000_000].pack("V")

      parser = DhanHQ::WS::WebsocketPacketParser.new(binary)

      expect(parser.header.feed_response_code).to eq(2)
      expect(parser.header.message_length).to eq(16)
      expect(parser.header.exchange_segment).to eq(1)
      expect(parser.header.security_id).to eq(1333)
    end
  end

  describe "unknown response codes" do
    it "returns nil without raising" do
      binary = header(99, 12, 1, 1333) + "junk".b

      expect(described_class.decode(binary)).to be_nil
    end
  end
end

# rubocop:enable RSpec/ExampleLength, RSpec/MultipleExpectations
