# frozen_string_literal: true

require "dhan_hq"

RSpec.describe DhanHQ::WS::MarketDepth::Decoder do
  subject(:decoder) { described_class.new }

  def frame(code, segment, security_id, rows, sequence: 0)
    body = rows.map { |price, qty, orders| [price, qty, orders].pack("EVV") }.join
    header = [body.bytesize + 12, code, segment].pack("s<CC") +
             [security_id].pack("l<") + [sequence].pack("V")
    header + body
  end

  describe "single bid frame" do
    it "decodes the 12-byte header and f64 price rows" do
      binary = frame(41, 2, 49_081, [[211.5, 1000, 3], [211.0, 2500, 7]])

      frames = decoder.decode(binary)

      expect(frames.size).to eq(1)
      f = frames.first
      expect(f[:side]).to eq(:bid)
      expect(f[:security_id]).to eq("49081")
      expect(f[:exchange_segment]).to eq("NSE_FNO")
      expect(f[:levels]).to eq([
                                 { price: 211.5, quantity: 1000, orders: 3 },
                                 { price: 211.0, quantity: 2500, orders: 7 }
                               ])
    end
  end

  describe "stacked bid + ask frames" do
    it "splits frames by consuming message_length bytes" do
      bid = frame(41, 1, 1333, [[100.25, 10, 1]])
      ask = frame(51, 1, 1333, [[100.75, 12, 2]])

      frames = decoder.decode(bid + ask)

      expect(frames.size).to eq(2)
      expect(frames.map { |f| f[:side] }).to eq(%i[bid ask])
      expect(frames.first[:levels].first[:price]).to eq(100.25)
      expect(frames.last[:levels].first[:price]).to eq(100.75)
    end
  end

  describe "20-level frame" do
    it "decodes a 332-byte twentydepth frame" do
      rows = 20.times.map { |i| [100.0 - i, 100 + i, i].pack("EVV") }.join
      binary = [rows.bytesize + 12, 41, 1].pack("s<CC") + [1333].pack("l<") + [42].pack("V") + rows

      frames = decoder.decode(binary)

      expect(frames.size).to eq(1)
      expect(frames.first[:levels].size).to eq(20)
      expect(frames.first[:levels].first[:price]).to eq(100.0)
      expect(frames.first[:levels].last[:orders]).to eq(19)
    end
  end

  describe "disconnect frame" do
    it "reports the little-endian disconnect code" do
      binary = [14, 50, 1].pack("s<CC") + [1333].pack("l<") + [0].pack("V") + [805].pack("v")

      frames = decoder.decode(binary)

      expect(frames.size).to eq(1)
      expect(frames.first[:side]).to eq(:disconnect)
      expect(frames.first[:disconnect_code]).to eq(805)
    end
  end

  describe "malformed input" do
    it "returns an empty array for JSON strings (old protocol assumption)" do
      expect(decoder.decode('{"Type":"depth_update"}')).to eq([])
    end

    it "returns an empty array for nil/empty input" do
      expect(decoder.decode(nil)).to eq([])
      expect(decoder.decode("")).to eq([])
    end

    it "skips truncated trailing frames but keeps earlier complete frames" do
      complete = frame(41, 1, 1333, [[100.25, 10, 1]])
      truncated = [64, 51, 1].pack("s<CC") + [1333].pack("l<") # claims 64 bytes, has 12

      frames = decoder.decode(complete + truncated)

      expect(frames.size).to eq(1)
      expect(frames.first[:side]).to eq(:bid)
    end
  end
end
