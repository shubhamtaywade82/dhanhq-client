# frozen_string_literal: true

require "timecop"

RSpec.describe DhanHQ::WS::Client do
  subject(:ws_client) { described_class.new(mode: :ticker) }

  # Captures the on_event proc the client hands to its connection so lifecycle
  # events can be driven without opening a real socket.
  let(:connection) { instance_spy(DhanHQ::WS::Connection) }
  let(:captured) { {} }

  before do
    DhanHQ.configure do |config|
      config.client_id = "1000000001"
      config.access_token = "test-token"
    end

    allow(DhanHQ::WS::Connection).to receive(:new) do |**kwargs, &_blk|
      captured[:on_event] = kwargs[:on_event]
      captured[:state] = kwargs[:state]
      connection
    end
    allow(DhanHQ::WS::Registry).to receive(:register)
    allow(DhanHQ::WS::Registry).to receive(:unregister)
  end

  after { DhanHQ.reset_configuration! }

  def emit_event(event, payload = nil)
    captured[:on_event].call(event, payload)
  end

  describe "lifecycle callbacks" do
    before { ws_client.start }

    it "forwards :open to subscribers" do
      seen = []
      ws_client.on(:open) { |payload| seen << payload }

      emit_event(:open, { resubscribed: [] })

      expect(seen).to eq([{ resubscribed: [] }])
    end

    it "forwards :reconnect with the restored subscriptions" do
      seen = []
      ws_client.on(:reconnect) { |payload| seen << payload }

      emit_event(:reconnect, { attempt: 1, resubscribed: [{ ExchangeSegment: "NSE_EQ", SecurityId: "11536" }] })

      expect(seen.first[:attempt]).to eq(1)
      expect(seen.first[:resubscribed].size).to eq(1)
    end

    it "forwards :close with the close code" do
      seen = []
      ws_client.on(:close) { |payload| seen << payload }

      emit_event(:close, { code: 1006, reason: "abnormal", reconnecting: true })

      expect(seen.first[:code]).to eq(1006)
      expect(seen.first[:reconnecting]).to be(true)
    end

    it "forwards :error" do
      seen = []
      ws_client.on(:error) { |payload| seen << payload }

      emit_event(:error, "boom")

      expect(seen).to eq(["boom"])
    end

    it "does not forward the internal :message event" do
      seen = []
      ws_client.on(:message) { |payload| seen << payload }

      emit_event(:message)

      expect(seen).to be_empty
    end

    it "survives a raising subscriber callback" do
      ws_client.on(:open) { raise "handler exploded" }

      expect { emit_event(:open, {}) }.not_to raise_error
    end
  end

  describe "health tracking" do
    before { ws_client.start }

    it "starts with no message timestamp" do
      expect(ws_client.last_message_at).to be_nil
      expect(ws_client.seconds_since_last_message).to be_nil
    end

    it "records the arrival of a frame" do
      emit_event(:message)

      expect(ws_client.last_message_at).to be_within(2).of(Time.now)
      expect(ws_client.seconds_since_last_message).to be < 2
    end

    it "records the connection timestamp on open and clears it on close" do
      emit_event(:open, {})
      expect(ws_client.connected_at).to be_within(2).of(Time.now)

      emit_event(:close, { code: 1006 })
      expect(ws_client.connected_at).to be_nil
    end

    it "counts reconnects" do
      expect(ws_client.reconnect_count).to eq(0)

      emit_event(:reconnect, { attempt: 1, resubscribed: [] })
      emit_event(:reconnect, { attempt: 2, resubscribed: [] })

      expect(ws_client.reconnect_count).to eq(2)
    end

    describe "#healthy?" do
      it "is false while disconnected" do
        allow(connection).to receive(:open?).and_return(false)

        expect(ws_client).not_to be_healthy
      end

      it "is true when connected and no frame has arrived yet" do
        allow(connection).to receive(:open?).and_return(true)

        expect(ws_client).to be_healthy
      end

      it "is true when a frame arrived recently" do
        allow(connection).to receive(:open?).and_return(true)
        emit_event(:message)

        expect(ws_client).to be_healthy
      end

      it "is false when the feed has gone quiet past the threshold" do
        allow(connection).to receive(:open?).and_return(true)
        emit_event(:message)

        Timecop.travel(Time.now + 120) do
          expect(ws_client).not_to be_healthy
        end
      end

      it "honours a custom staleness threshold" do
        allow(connection).to receive(:open?).and_return(true)
        emit_event(:message)

        Timecop.travel(Time.now + 20) do
          expect(ws_client.healthy?(stale_after: 10)).to be(false)
          expect(ws_client.healthy?(stale_after: 60)).to be(true)
        end
      end
    end

    describe "#health" do
      it "reports a monitoring snapshot" do
        allow(connection).to receive(:open?).and_return(true)
        emit_event(:message)

        snapshot = ws_client.health

        expect(snapshot).to include(mode: :ticker, started: true, connected: true, healthy: true)
        expect(snapshot[:reconnect_count]).to eq(0)
        expect(snapshot[:subscription_count]).to eq(0)
      end
    end
  end

  describe "#subscriptions" do
    before { ws_client.start }

    it "is empty before anything is subscribed" do
      expect(ws_client.subscriptions).to eq([])
    end

    it "reflects the subscription state the connection replays on reconnect" do
      captured[:state].mark_subscribed!([{ ExchangeSegment: "NSE_EQ", SecurityId: "11536" }])

      expect(ws_client.subscriptions).to eq(["NSE_EQ:11536"])
    end
  end
end
