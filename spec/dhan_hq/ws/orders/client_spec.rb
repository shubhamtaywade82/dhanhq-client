# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::WS::Orders::Client do
  let(:client) { described_class.new }
  let(:order_update) do
    # Use double instead of instance_double since OrderUpdate uses dynamic attributes
    double(
      "OrderUpdate",
      order_no: "12345",
      status: "PENDING",
      traded_qty: 0,
      symbol: "RELIANCE"
    )
  end

  before do
    DhanHQ.configure_with_env
    allow(DhanHQ::WS::Registry).to receive(:register)
    allow(DhanHQ::WS::Registry).to receive(:unregister)
  end

  describe "#initialize" do
    it "initializes order tracker and timestamps" do
      expect(client.instance_variable_get(:@order_tracker)).to be_a(Concurrent::Map)
      expect(client.instance_variable_get(:@order_timestamps)).to be_a(Concurrent::Map)
    end
  end

  describe "#handle_order_update" do
    before do
      allow(DhanHQ::Models::OrderUpdate).to receive(:from_websocket_message).and_return(order_update)
      allow(client).to receive(:emit)
    end

    it "tracks order updates with timestamp" do
      client.send(:handle_order_update, order_update)
      expect(client.order_state("12345")).to eq(order_update)
      expect(client.instance_variable_get(:@order_timestamps)["12345"]).to be_a(Time)
    end

    it "triggers cleanup when tracker exceeds max size" do
      allow(client).to receive(:cleanup_old_orders)
      # Fill tracker to max
      allow(client.instance_variable_get(:@order_tracker)).to receive(:size).and_return(10_001)
      client.send(:handle_order_update, order_update)
      expect(client).to have_received(:cleanup_old_orders)
    end
  end

  describe "#cleanup_old_orders" do
    before do
      client.instance_variable_set(:@order_tracker, Concurrent::Map.new)
      client.instance_variable_set(:@order_timestamps, Concurrent::Map.new)
    end

    it "removes orders older than MAX_ORDER_AGE" do
      old_time = Time.now - (described_class::MAX_ORDER_AGE + 1)
      client.instance_variable_get(:@order_tracker)["old"] = order_update
      client.instance_variable_get(:@order_timestamps)["old"] = old_time

      client.instance_variable_get(:@order_tracker)["new"] = order_update
      client.instance_variable_get(:@order_timestamps)["new"] = Time.now

      client.send(:cleanup_old_orders)

      expect(client.order_state("old")).to be_nil
      expect(client.order_state("new")).to eq(order_update)
    end

    it "removes orders when tracker exceeds max size" do
      # Add more than max orders
      (described_class::MAX_TRACKED_ORDERS + 10).times do |i|
        client.instance_variable_get(:@order_tracker)[i.to_s] = order_update
        client.instance_variable_get(:@order_timestamps)[i.to_s] = Time.now
      end

      client.send(:cleanup_old_orders)

      expect(client.instance_variable_get(:@order_tracker).size).to be <= described_class::MAX_TRACKED_ORDERS
    end
  end

  describe "#start and #stop" do
    let(:connection) { instance_double(DhanHQ::WS::Orders::Connection) }

    before do
      allow(DhanHQ::WS::Orders::Connection).to receive(:new).and_return(connection)
      allow(connection).to receive(:on)
      allow(connection).to receive(:start)
      allow(connection).to receive(:stop)
    end

    it "starts cleanup thread on start" do
      client.start
      expect(client.instance_variable_get(:@cleanup_thread)).to be_a(Thread)
      client.stop
    end

    it "stops cleanup thread on stop" do
      client.start
      cleanup_thread = client.instance_variable_get(:@cleanup_thread)
      client.stop
      sleep(0.1) # Give thread time to stop
      expect(cleanup_thread.alive?).to be false
    end
  end

  describe "#emit" do
    it "creates frozen snapshot of callbacks" do
      callback_called = false
      client.on(:test) { callback_called = true }

      # Modify callbacks during emit
      client.send(:emit, :test, nil)
      expect(callback_called).to be true
    end

    it "handles errors in callbacks gracefully" do
      client.on(:test) { raise StandardError, "Callback error" }
      expect(DhanHQ.logger).to receive(:error).with(/Error in event handler/)
      expect { client.send(:emit, :test, nil) }.not_to raise_error
    end
  end
end
