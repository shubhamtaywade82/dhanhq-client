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
    end
  end
end
