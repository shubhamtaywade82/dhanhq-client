# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Packets::DepthDeltaPacket do
  # Layout (little-endian):
  #   uint32 bid_quantity     (4)
  #   uint32 ask_quantity     (4)
  #   uint16 no_of_bid_orders (2)
  #   uint16 no_of_ask_orders (2)
  #   float  bid_price        (4)
  #   float  ask_price        (4)
  # Total: 20 bytes

  def build_depth_delta(bid_qty:, ask_qty:, no_bid:, no_ask:, bid_price:, ask_price:)
    [bid_qty].pack("L<") +
      [ask_qty].pack("L<") +
      [no_bid].pack("S<") +
      [no_ask].pack("S<") +
      [bid_price].pack("e") +
      [ask_price].pack("e")
  end

  let(:binary) do
    build_depth_delta(
      bid_qty: 500, ask_qty: 300,
      no_bid: 10, no_ask: 8,
      bid_price: 1499.50, ask_price: 1500.25
    )
  end

  describe ".read" do
    subject(:pkt) { described_class.read(binary) }

    it { expect(pkt.bid_quantity).to eq(500) }
    it { expect(pkt.ask_quantity).to eq(300) }
    it { expect(pkt.no_of_bid_orders).to eq(10) }
    it { expect(pkt.no_of_ask_orders).to eq(8) }
    it { expect(pkt.bid_price).to be_within(0.01).of(1499.50) }
    it { expect(pkt.ask_price).to be_within(0.01).of(1500.25) }
  end
end
