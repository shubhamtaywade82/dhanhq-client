# frozen_string_literal: true

RSpec.describe DhanHQ::WS do
  describe ".debug_frame" do
    before do
      DhanHQ.configure do |config|
        config.client_id = "1000000001"
        config.access_token = "test-token"
      end
      allow(DhanHQ.logger).to receive(:debug).and_call_original
    end

    after { DhanHQ.reset_configuration! }

    context "when ws_debug is disabled (the default)" do
      it "does not touch the logger at all" do
        described_class.debug_frame("Connection", "\x00\x01\x02")

        expect(DhanHQ.logger).not_to have_received(:debug)
      end
    end

    context "when ws_debug is enabled" do
      before { DhanHQ.configuration.ws_debug = true }

      it "logs the frame as a hex dump tagged with the source and byte count" do
        described_class.debug_frame("Connection", "\x00\x01\x02")

        expect(DhanHQ.logger).to have_received(:debug).with(
          "[DhanHQ::WS::Connection] frame (3 bytes): 000102"
        )
      end

      it "does not raise on an empty frame" do
        expect { described_class.debug_frame("Connection", "") }.not_to raise_error
      end

      it "hex-dumps a text frame (JSON order update) the same way as a binary frame -- no shape-specific branching" do
        data = '{"Type":"order_alert"}'

        described_class.debug_frame("Orders::Connection", data)

        expect(DhanHQ.logger).to have_received(:debug).with(
          "[DhanHQ::WS::Orders::Connection] frame (#{data.bytesize} bytes): #{data.unpack1("H*")}"
        )
      end

      it "does not truncate a frame at exactly the cap" do
        data = ("\x02" * DhanHQ::WS::DEBUG_FRAME_MAX_BYTES).b

        described_class.debug_frame("MarketDepth", data)

        expect(DhanHQ.logger).to have_received(:debug).with(
          "[DhanHQ::WS::MarketDepth] frame (256 bytes): #{"02" * 256}"
        )
      end

      it "truncates a frame over the cap, but still reports the full byte count" do
        data = ("\x01" * 300).b # e.g. a full market depth packet

        described_class.debug_frame("MarketDepth", data)

        expect(DhanHQ.logger).to have_received(:debug).with(
          "[DhanHQ::WS::MarketDepth] frame (300 bytes): #{"01" * 256}...truncated"
        )
      end
    end
  end
end
