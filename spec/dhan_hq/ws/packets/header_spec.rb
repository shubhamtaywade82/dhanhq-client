# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::Header do
  # Layout (big-endian except security_id):
  #   uint8  feed_response_code  (1 byte)
  #   uint16 message_length      (2 bytes, big-endian)
  #   uint8  exchange_segment    (1 byte)
  #   int32le security_id        (4 bytes, little-endian)
  def build_header(code:, length:, segment:, security_id:)
    [code].pack("C") +
      [length].pack("n") +
      [segment].pack("C") +
      [security_id].pack("l<")
  end

  describe ".read" do
    it "parses feed_response_code" do
      binary = build_header(code: 2, length: 16, segment: 1, security_id: 11536)
      hdr = described_class.read(binary)
      expect(hdr.feed_response_code).to eq(2)
    end

    it "parses message_length" do
      binary = build_header(code: 4, length: 44, segment: 1, security_id: 1333)
      hdr = described_class.read(binary)
      expect(hdr.message_length).to eq(44)
    end

    it "parses exchange_segment" do
      binary = build_header(code: 8, length: 100, segment: 3, security_id: 500)
      hdr = described_class.read(binary)
      expect(hdr.exchange_segment).to eq(3)
    end

    it "parses security_id as little-endian int32" do
      binary = build_header(code: 2, length: 16, segment: 1, security_id: 2881)
      hdr = described_class.read(binary)
      expect(hdr.security_id).to eq(2881)
    end

    it "handles a large security_id" do
      binary = build_header(code: 5, length: 12, segment: 2, security_id: 999_999)
      hdr = described_class.read(binary)
      expect(hdr.security_id).to eq(999_999)
    end
  end
end
