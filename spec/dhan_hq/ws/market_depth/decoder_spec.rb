# frozen_string_literal: true

RSpec.describe DhanHQ::WS::MarketDepth::Decoder do
  # 12-byte header + rows, little-endian, as documented for Full Market Depth.
  def side_packet(code:, security_id:, rows:, segment: 1, tail: 0, length: nil, pad_to: nil)
    body = rows.map { |price, qty, orders| [price, qty, orders].pack("EL<L<") }.join
    body += "\x00".b * (((pad_to || rows.size) - rows.size) * 16)
    [length || (12 + body.bytesize), code, segment, security_id, tail].pack("s<CCl<L<") + body
  end

  describe "20-level" do
    subject(:decoder) { described_class.new(depth_level: 20) }

    it "decodes stacked bid and ask packets for one instrument" do
      frame = side_packet(code: 41, security_id: 1333, rows: [[1520.5, 100, 3], [1520.0, 50, 1]], pad_to: 20) +
              side_packet(code: 51, security_id: 1333, rows: [[1521.0, 75, 2]], pad_to: 20)

      bid, ask = decoder.decode(frame)

      expect(bid).to include(type: :bid, exchange_segment: "NSE_EQ", security_id: "1333")
      expect(bid[:levels]).to eq([{ price: 1520.5, quantity: 100, orders: 3 }, { price: 1520.0, quantity: 50, orders: 1 }])
      expect(ask[:type]).to eq(:ask)
      expect(ask[:levels]).to eq([{ price: 1521.0, quantity: 75, orders: 2 }])
    end

    it "accepts a byte-array frame as delivered by faye-websocket" do
      frame = side_packet(code: 41, security_id: 11_536, segment: 2, rows: [[100.25, 10, 1]], pad_to: 20)

      packet = decoder.decode(frame.bytes).first

      expect(packet).to include(type: :bid, exchange_segment: "NSE_FNO", security_id: "11536")
    end

    it "stays aligned when the length field excludes the header" do
      frame = side_packet(code: 41, security_id: 1, rows: [[10.0, 1, 1]], pad_to: 20, length: 320) +
              side_packet(code: 51, security_id: 1, rows: [[11.0, 2, 1]], pad_to: 20, length: 320)

      expect(decoder.decode(frame).map { |p| p[:levels].first[:price] }).to eq([10.0, 11.0])
    end

    it "decodes a server disconnect packet" do
      frame = [14, 50, 1, 1333, 0].pack("s<CCl<L<") + [805].pack("s<")

      expect(decoder.decode(frame)).to eq([{ type: :disconnect, exchange_segment: "NSE_EQ", security_id: "1333", code: 805 }])
    end

    it "returns no packets for truncated or empty frames instead of raising" do
      expect(decoder.decode("")).to eq([])
      expect(decoder.decode("\x01\x02".b)).to eq([])
    end

    it "drops the rest of the frame on an unknown response code" do
      frame = side_packet(code: 99, security_id: 1, rows: [[1.0, 1, 1]], pad_to: 20)

      expect(decoder.decode(frame)).to eq([])
    end
  end

  describe "200-level" do
    subject(:decoder) { described_class.new(depth_level: 200) }

    it "reads the row count from header bytes 8-11" do
      rows = Array.new(3) { |i| [200.0 - i, 10 + i, 1] }
      frame = side_packet(code: 41, security_id: 1333, rows: rows, tail: 3)

      expect(decoder.decode(frame).first[:levels].size).to eq(3)
    end
  end
end
