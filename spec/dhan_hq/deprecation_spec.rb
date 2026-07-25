# frozen_string_literal: true

require "concurrent"

RSpec.describe DhanHQ::Deprecation do
  before { described_class.reset! }

  after { described_class.reset! }

  describe ".warn_once" do
    it "logs the first time a key is seen" do
      allow(DhanHQ.logger).to receive(:warn)

      described_class.warn_once("Order.place", "move to place!")

      expect(DhanHQ.logger).to have_received(:warn).with(/DEPRECATION: move to place!/)
    end

    it "stays silent on every later occurrence of the same key" do
      allow(DhanHQ.logger).to receive(:warn)

      3.times { described_class.warn_once("Order.place", "move to place!") }

      expect(DhanHQ.logger).to have_received(:warn).once
    end

    it "warns separately for each distinct key" do
      allow(DhanHQ.logger).to receive(:warn)

      described_class.warn_once("Order.place", "a")
      described_class.warn_once("Order.cancel", "b")

      expect(DhanHQ.logger).to have_received(:warn).twice
    end

    it "treats a symbol and its string form as the same key" do
      allow(DhanHQ.logger).to receive(:warn)

      described_class.warn_once(:"Order.place", "a")
      described_class.warn_once("Order.place", "a")

      expect(DhanHQ.logger).to have_received(:warn).once
    end

    it "records the key it warned about" do
      described_class.warn_once("Order.place", "a")

      expect(described_class.warned_keys).to eq(["Order.place"])
    end

    it "warns again after a reset" do
      allow(DhanHQ.logger).to receive(:warn)

      described_class.warn_once("Order.place", "a")
      described_class.reset!
      described_class.warn_once("Order.place", "a")

      expect(DhanHQ.logger).to have_received(:warn).twice
    end
  end

  describe "thread safety" do
    it "lets exactly one of many concurrent threads win the same key" do
      warned = Concurrent::AtomicFixnum.new(0)
      allow(DhanHQ.logger).to receive(:warn) { warned.increment }

      Array.new(8) { Thread.new { described_class.warn_once("Order.place", "a") } }.each(&:join)

      expect(warned.value).to eq(1)
    end
  end
end
