# frozen_string_literal: true

RSpec.describe DhanHQ::WS::Connection do
  subject(:connection) do
    described_class.new(url: "wss://example.test", mode: :ticker, bus: bus, state: state, on_event: on_event)
  end

  let(:bus) { DhanHQ::WS::CmdBus.new }
  let(:state) { DhanHQ::WS::SubState.new }
  let(:events) { [] }
  let(:on_event) { ->(event, payload) { events << [event, payload] } }

  # Stands in for the Faye websocket so subscribe frames can be inspected without
  # a live socket or a running EventMachine reactor.
  let(:socket) { instance_double(Faye::WebSocket::Client, send: true) }

  before do
    allow(EM).to receive(:add_periodic_timer).and_return(:timer)
    connection.instance_variable_set(:@ws, socket)
  end

  def sent_frames
    frames = []
    allow(socket).to receive(:send) { |data| frames << JSON.parse(data) }
    frames
  end

  describe "#handle_open" do
    it "reports :open without :reconnect on the first session" do
      connection.send(:handle_open, 1)

      expect(events.map(&:first)).to eq([:open])
    end

    it "reports :reconnect before :open on later sessions" do
      connection.send(:handle_open, 3)

      expect(events.map(&:first)).to eq(%i[reconnect open])
      expect(events.first.last[:attempt]).to eq(2)
    end

    it "replays the subscription snapshot as a subscribe frame on reconnect" do
      frames = sent_frames
      state.mark_subscribed!([{ ExchangeSegment: "NSE_EQ", SecurityId: "11536" },
                              { ExchangeSegment: "NSE_FNO", SecurityId: "43492" }])

      connection.send(:handle_open, 2)

      expect(frames.size).to eq(1)
      expect(frames.first["InstrumentCount"]).to eq(2)
      expect(frames.first["InstrumentList"]).to contain_exactly(
        { "ExchangeSegment" => "NSE_EQ", "SecurityId" => "11536" },
        { "ExchangeSegment" => "NSE_FNO", "SecurityId" => "43492" }
      )
    end

    it "reports which instruments were restored" do
      state.mark_subscribed!([{ ExchangeSegment: "NSE_EQ", SecurityId: "11536" }])

      connection.send(:handle_open, 2)

      reconnect = events.find { |event, _| event == :reconnect }.last
      expect(reconnect[:resubscribed]).to eq([{ ExchangeSegment: "NSE_EQ", SecurityId: "11536" }])
    end

    it "sends no subscribe frame when nothing is subscribed" do
      frames = sent_frames

      connection.send(:handle_open, 2)

      expect(frames).to be_empty
    end

    it "starts the command drain timer" do
      connection.send(:handle_open, 1)

      expect(EM).to have_received(:add_periodic_timer).with(0.25)
    end
  end

  describe "#notify" do
    it "swallows an exception raised by the event handler" do
      exploding = described_class.new(url: "wss://example.test", mode: :ticker, bus: bus, state: state,
                                      on_event: ->(_event, _payload) { raise "handler exploded" })

      expect { exploding.send(:notify, :open, nil) }.not_to raise_error
    end

    it "is a no-op when no handler is registered" do
      silent = described_class.new(url: "wss://example.test", mode: :ticker, bus: bus, state: state)

      expect { silent.send(:notify, :open, nil) }.not_to raise_error
    end
  end
end
