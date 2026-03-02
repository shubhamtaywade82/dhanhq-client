# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::QuotePacket do
  # Layout (little-endian):
  #   float32 ltp             (4)
  #   uint16  last_trade_qty  (2)
  #   uint32  ltt             (4)
  #   float32 atp             (4)
  #   uint32  volume          (4)
  #   int32   total_sell_qty  (4)
  #   int32   total_buy_qty   (4)
  #   float32 day_open        (4)
  #   float32 day_close       (4)
  #   float32 day_high        (4)
  #   float32 day_low         (4)
  # Total: 44 bytes

  def build_quote(ltp:, last_trade_qty:, ltt:, atp:, volume:,
                  total_sell_qty:, total_buy_qty:,
                  day_open:, day_close:, day_high:, day_low:)
    [ltp].pack("e") +
      [last_trade_qty].pack("S<") +
      [ltt].pack("L<") +
      [atp].pack("e") +
      [volume].pack("L<") +
      [total_sell_qty].pack("l<") +
      [total_buy_qty].pack("l<") +
      [day_open].pack("e") +
      [day_close].pack("e") +
      [day_high].pack("e") +
      [day_low].pack("e")
  end

  let(:binary) do
    build_quote(
      ltp: 1500.0, last_trade_qty: 10, ltt: 1_700_000_000,
      atp: 1499.5, volume: 50_000,
      total_sell_qty: 200, total_buy_qty: 300,
      day_open: 1480.0, day_close: 1490.0,
      day_high: 1510.0, day_low: 1470.0
    )
  end

  describe ".read" do
    subject(:pkt) { described_class.read(binary) }

    it { expect(pkt.ltp).to be_within(0.01).of(1500.0) }
    it { expect(pkt.last_trade_qty).to eq(10) }
    it { expect(pkt.ltt).to eq(1_700_000_000) }
    it { expect(pkt.atp).to be_within(0.01).of(1499.5) }
    it { expect(pkt.volume).to eq(50_000) }
    it { expect(pkt.total_sell_qty).to eq(200) }
    it { expect(pkt.total_buy_qty).to eq(300) }
    it { expect(pkt.day_open).to be_within(0.01).of(1480.0) }
    it { expect(pkt.day_close).to be_within(0.01).of(1490.0) }
    it { expect(pkt.day_high).to be_within(0.01).of(1510.0) }
    it { expect(pkt.day_low).to be_within(0.01).of(1470.0) }
  end
end
