# frozen_string_literal: true

RSpec.describe DhanHQ::WS::BaseConnection do
  subject(:connection) { described_class.new(url: "wss://example.com") }

  let(:event) { Struct.new(:data).new("\x00\x01") }

  describe "#handle_message" do
    it "logs the raw frame via WS.debug_frame before dispatching" do
      allow(DhanHQ::WS).to receive(:debug_frame)

      connection.send(:handle_message, event)

      expect(DhanHQ::WS).to have_received(:debug_frame).with(described_class.name, "\x00\x01")
    end

    it "still emits :raw regardless of ws_debug" do
      seen = []
      connection.on(:raw) { |data| seen << data }

      connection.send(:handle_message, event)

      expect(seen).to eq(["\x00\x01"])
    end
  end
end
