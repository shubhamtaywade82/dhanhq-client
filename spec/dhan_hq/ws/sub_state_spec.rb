# frozen_string_literal: true

RSpec.describe DhanHQ::WS::SubState do
  subject(:state) { described_class.new }

  let(:reliance) { { ExchangeSegment: "NSE_EQ", SecurityId: "11536" } }
  let(:nifty_fut) { { ExchangeSegment: "NSE_FNO", SecurityId: "43492" } }

  describe "#want_sub" do
    it "returns instruments that are not yet subscribed" do
      expect(state.want_sub([reliance, nifty_fut])).to eq([reliance, nifty_fut])
    end

    it "filters out instruments already subscribed, so no duplicate frame is sent" do
      state.mark_subscribed!([reliance])

      expect(state.want_sub([reliance, nifty_fut])).to eq([nifty_fut])
    end
  end

  describe "#want_unsub" do
    it "returns only instruments that are currently subscribed" do
      state.mark_subscribed!([reliance])

      expect(state.want_unsub([reliance, nifty_fut])).to eq([reliance])
    end
  end

  describe "#mark_unsubscribed!" do
    it "drops the instrument from the desired set" do
      state.mark_subscribed!([reliance, nifty_fut])
      state.mark_unsubscribed!([reliance])

      expect(state.snapshot).to eq(["NSE_FNO:43492"])
    end
  end

  describe "#resubscribe_payload" do
    it "is empty before anything is subscribed" do
      expect(state.resubscribe_payload).to eq([])
    end

    it "renders the desired set as instrument hashes for a subscribe frame" do
      state.mark_subscribed!([reliance, nifty_fut])

      expect(state.resubscribe_payload).to contain_exactly(reliance, nifty_fut)
    end

    it "reflects unsubscribes, so a reconnect does not restore dropped instruments" do
      state.mark_subscribed!([reliance, nifty_fut])
      state.mark_unsubscribed!([reliance])

      expect(state.resubscribe_payload).to eq([nifty_fut])
    end

    it "round-trips a security id containing no separator ambiguity" do
      state.mark_subscribed!([{ ExchangeSegment: "IDX_I", SecurityId: "13" }])

      expect(state.resubscribe_payload).to eq([{ ExchangeSegment: "IDX_I", SecurityId: "13" }])
    end
  end
end
