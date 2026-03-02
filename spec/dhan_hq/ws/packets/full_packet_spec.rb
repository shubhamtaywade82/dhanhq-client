# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::FullPacket do
  # Layout (little-endian):
  #   float32 ltp            (4)
  #   uint16  last_trade_qty (2)
  #   uint32  ltt            (4)
  #   float32 atp            (4)
  #   uint32  volume         (4)
  #   int32   total_sell_qty (4)
  #   int32   total_buy_qty  (4)
  #   int32   open_interest  (4)
  #   int32   highest_oi     (4)
  #   int32   lowest_oi      (4)
  #   float32 day_open       (4)
  #   float32 day_close      (4)
  #   float32 day_high       (4)
  #   float32 day_low        (4)
  #   5 × MarketDepthLevel (each 20 bytes: uint32 bid_qty, uint32 ask_qty, uint16 bid_orders, uint16 ask_orders, float bid_price, float ask_price)
  # Total header: 56 bytes + 100 bytes depth = 156 bytes

  def build_depth_level(bid_qty:, ask_qty:, no_bid:, no_ask:, bid_price:, ask_price:)
    [bid_qty].pack("L<") +
      [ask_qty].pack("L<") +
      [no_bid].pack("S<") +
      [no_ask].pack("S<") +
      [bid_price].pack("e") +
      [ask_price].pack("e")
  end

  let(:depth_levels) do
    5.times.map do |i|
      build_depth_level(
        bid_qty: 100 + i, ask_qty: 200 + i,
        no_bid: 5 + i, no_ask: 3 + i,
        bid_price: 1499.0 - i, ask_price: 1500.0 + i
      )
    end.join
  end

  let(:binary) do
    [1500.0].pack("e") +    # ltp
      [25].pack("S<") +       # last_trade_qty
      [1_700_000_000].pack("L<") + # ltt
      [1499.5].pack("e") +   # atp
      [75_000].pack("L<") +  # volume
      [400].pack("l<") +     # total_sell_qty
      [600].pack("l<") +     # total_buy_qty
      [50_000].pack("l<") +  # open_interest
      [60_000].pack("l<") +  # highest_oi
      [40_000].pack("l<") +  # lowest_oi
      [1480.0].pack("e") +   # day_open
      [1490.0].pack("e") +   # day_close
      [1515.0].pack("e") +   # day_high
      [1470.0].pack("e") +   # day_low
      depth_levels
  end

  describe ".read" do
    subject(:pkt) { described_class.read(binary) }

    it { expect(pkt.ltp).to be_within(0.01).of(1500.0) }
    it { expect(pkt.last_trade_qty).to eq(25) }
    it { expect(pkt.ltt).to eq(1_700_000_000) }
    it { expect(pkt.atp).to be_within(0.01).of(1499.5) }
    it { expect(pkt.volume).to eq(75_000) }
    it { expect(pkt.total_sell_qty).to eq(400) }
    it { expect(pkt.total_buy_qty).to eq(600) }
    it { expect(pkt.open_interest).to eq(50_000) }
    it { expect(pkt.highest_oi).to eq(60_000) }
    it { expect(pkt.lowest_oi).to eq(40_000) }
    it { expect(pkt.day_open).to be_within(0.01).of(1480.0) }
    it { expect(pkt.day_high).to be_within(0.01).of(1515.0) }
    it { expect(pkt.day_low).to be_within(0.01).of(1470.0) }

    it "parses 5 market depth levels" do
      expect(pkt.market_depth.length).to eq(5)
    end

    it "parses the first depth level bid_price" do
      expect(pkt.market_depth[0].bid_price).to be_within(0.01).of(1499.0)
    end

    it "parses the first depth level ask_price" do
      expect(pkt.market_depth[0].ask_price).to be_within(0.01).of(1500.0)
    end
  end
end
