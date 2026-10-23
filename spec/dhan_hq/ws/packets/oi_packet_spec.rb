# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::OiPacket do
  # Layout (little-endian):
  #   int32 open_interest (4 bytes)

  describe ".read" do
    it "parses open_interest" do
      binary = [125_000].pack("l<")
      pkt = described_class.read(binary)
      expect(pkt.open_interest).to eq(125_000)
    end

    it "handles zero open interest" do
      binary = [0].pack("l<")
      pkt = described_class.read(binary)
      expect(pkt.open_interest).to eq(0)
    end

    it "handles large open interest values" do
      binary = [50_000_000].pack("l<")
      pkt = described_class.read(binary)
      expect(pkt.open_interest).to eq(50_000_000)
    end
  end
end
