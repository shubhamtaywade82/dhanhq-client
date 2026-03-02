# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::PrevClosePacket do
  # Layout (little-endian):
  #   float32 prev_close (4 bytes)
  #   int32   oi_prev    (4 bytes)

  describe ".read" do
    it "parses prev_close as a float" do
      binary = [2100.50].pack("e") + [80_000].pack("l<")
      pkt = described_class.read(binary)
      expect(pkt.prev_close).to be_within(0.01).of(2100.50)
    end

    it "parses oi_prev as an integer" do
      binary = [100.0].pack("e") + [42_000].pack("l<")
      pkt = described_class.read(binary)
      expect(pkt.oi_prev).to eq(42_000)
    end

    it "handles zero values" do
      binary = [0.0].pack("e") + [0].pack("l<")
      pkt = described_class.read(binary)
      expect(pkt.prev_close).to eq(0.0)
      expect(pkt.oi_prev).to eq(0)
    end
  end
end
