# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Registry do
  # A minimal stand-in with the same stop-time behaviour as
  # DhanHQ::WS::Client and DhanHQ::WS::Orders::Client: both call
  # Registry.unregister(self) from #stop, and both emit :close.
  # The market feed client unregisters *before* emitting :close;
  # the orders client emits *before* unregistering.
  let(:close_events) { [] }

  # NOTE: the events array is passed in explicitly because singleton-method
  # bodies run with the client object as self — a bare `close_events` (let)
  # would raise NoMethodError inside #stop.
  def fake_client(mode:, events:)
    stops = 0
    client = Object.new
    client.define_singleton_method(:stop) do
      stops += 1
      if mode == :unregister_first
        DhanHQ::WS::Registry.unregister(client)
        events << :close
      else
        events << :close
        DhanHQ::WS::Registry.unregister(client)
      end
    end
    client.define_singleton_method(:stop_count) { stops }
    client
  end

  after do
    described_class.instance_variable_get(:@clients).clear
  end

  describe ".stop_all" do
    it "does not deadlock when clients unregister themselves from stop" do
      market_feed = fake_client(mode: :unregister_first, events: close_events)
      orders = fake_client(mode: :emit_first, events: close_events)
      described_class.register(market_feed)
      described_class.register(orders)

      # Regression: stop_all used to hold the registry mutex while calling
      # c.stop; both real clients call Registry.unregister (same mutex) from
      # stop, raising "ThreadError: deadlock; recursive locking". The rescue
      # hid it and the market feed's close listeners never ran.
      expect { described_class.stop_all }.not_to raise_error

      expect(market_feed.stop_count).to eq(1)
      expect(orders.stop_count).to eq(1)
    end

    it "still notifies close listeners of the market feed client" do
      market_feed = fake_client(mode: :unregister_first, events: close_events)
      described_class.register(market_feed)

      described_class.stop_all

      expect(close_events).to include(:close)
    end

    it "notifies close listeners of the orders client (emit-before-unregister)" do
      orders = fake_client(mode: :emit_first, events: close_events)
      described_class.register(orders)

      described_class.stop_all

      expect(close_events).to include(:close)
    end

    it "empties the registry even if a client's stop raises" do
      boom = Object.new
      def boom.stop
        raise StandardError, "socket already gone"
      end
      healthy = fake_client(mode: :unregister_first, events: close_events)

      described_class.register(boom)
      described_class.register(healthy)

      expect { described_class.stop_all }.not_to raise_error

      expect(healthy.stop_count).to eq(1)
      expect(described_class.instance_variable_get(:@clients)).to be_empty
    end

    it "is safe to call when nothing is registered" do
      expect { described_class.stop_all }.not_to raise_error
    end

    it "unregister becomes a no-op delete for already-removed clients" do
      client = fake_client(mode: :unregister_first, events: close_events)
      described_class.register(client)
      described_class.stop_all

      expect { described_class.unregister(client) }.not_to raise_error
      expect(described_class.instance_variable_get(:@clients)).to be_empty
    end
  end
end
