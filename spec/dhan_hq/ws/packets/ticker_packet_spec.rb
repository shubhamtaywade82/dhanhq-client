# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::TickerPacket do
  # Layout (little-endian):
  #   float32 ltp (4 bytes)
  #   int32   ltt (4 bytes)

  def build_ticker(ltp:, ltt:)
    [ltp].pack("e") + [ltt].pack("l<")
  end

  describe ".read" do
    it "parses ltp as a float" do
      binary = build_ticker(ltp: 1500.0, ltt: 1_700_000_000)
      pkt = described_class.read(binary)
      expect(pkt.ltp).to be_within(0.01).of(1500.0)
    end

    it "parses ltt as an integer timestamp" do
      binary = build_ticker(ltp: 200.5, ltt: 1_700_000_000)
      pkt = described_class.read(binary)
      expect(pkt.ltt).to eq(1_700_000_000)
    end

    it "handles fractional prices" do
      binary = build_ticker(ltp: 1234.56, ltt: 0)
      pkt = described_class.read(binary)
      expect(pkt.ltp).to be_within(0.01).of(1234.56)
    end

    it "handles zero ltp" do
      binary = build_ticker(ltp: 0.0, ltt: 1)
      pkt = described_class.read(binary)
      expect(pkt.ltp).to eq(0.0)
    end
  end
end
