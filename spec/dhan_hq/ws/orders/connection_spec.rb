# frozen_string_literal: true

RSpec.describe DhanHQ::WS::Orders::Connection do
  subject(:connection) { described_class.new(url: "wss://example.com") }

  let(:event) { Struct.new(:data).new('{"Type":"order_alert"}') }

  describe "#handle_message" do
    it "logs the raw frame via WS.debug_frame before parsing" do
      allow(DhanHQ::WS).to receive(:debug_frame)

      connection.send(:handle_message, event)

      expect(DhanHQ::WS).to have_received(:debug_frame).with(described_class.name, '{"Type":"order_alert"}')
    end

    it "still parses and emits :message as before" do
      seen = []
      connection.on(:message) { |msg| seen << msg }

      connection.send(:handle_message, event)

      expect(seen).to eq([{ Type: "order_alert" }])
    end

    it "still emits :error on malformed JSON rather than raising" do
      bad_event = Struct.new(:data).new("not json")
      seen = []
      connection.on(:error) { |err| seen << err }

      expect { connection.send(:handle_message, bad_event) }.not_to raise_error
      expect(seen.size).to eq(1)
      expect(seen.first).to be_a(JSON::ParserError)
    end
  end
end
