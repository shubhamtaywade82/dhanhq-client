# frozen_string_literal: true

require "dhan_hq"

RSpec.describe DhanHQ::Constants do
  describe "nested constant modules" do
    it "defines ExchangeSegment values" do
      expect(described_class::ExchangeSegment::ALL).to include("NSE_EQ", "BSE_FNO", "IDX_I")
    end

    it "defines FeedRequest codes" do
      expect(described_class::FeedRequest::SUBSCRIBE_TICKER).to eq(15)
      expect(described_class::FeedRequest::UNSUBSCRIBE_DEPTH).to eq(24)
    end

    it "defines TradingErrorCode values" do
      expect(described_class::TradingErrorCode::INVALID_AUTHENTICATION).to eq("DH-901")
      expect(described_class::TradingErrorCode::OTHERS).to eq("DH-910")
    end

    it "defines DataErrorCode values" do
      expect(described_class::DataErrorCode::INVALID_REQUEST).to eq(814)
    end
  end

  describe "backward compatibility" do
    it "keeps legacy arrays aligned with nested modules" do
      expect(described_class::TRANSACTION_TYPES).to eq(described_class::TransactionType::ALL)
      expect(described_class::EXCHANGE_SEGMENTS).to eq(described_class::ExchangeSegment::ALL)
      expect(described_class::ORDER_TYPES).to eq(described_class::OrderType::ALL)
    end

    it "keeps legacy aliases" do
      expect(described_class::NSE).to eq("NSE_EQ")
      expect(described_class::INTRA).to eq("INTRADAY")
      expect(described_class::SL).to eq("STOP_LOSS")
    end
  end

  describe ".valid?" do
    it "returns true for valid entries in module name symbols" do
      expect(described_class.valid?(:ExchangeSegment, "NSE_EQ")).to be(true)
    end

    it "returns true for valid entries in direct module refs" do
      expect(described_class.valid?(described_class::OrderType, "MARKET")).to be(true)
    end

    it "returns false for invalid values or unknown modules" do
      expect(described_class.valid?(:OrderType, "INVALID")).to be(false)
      expect(described_class.valid?(:UnknownThing, "X")).to be(false)
    end
  end

  describe ".all_for" do
    it "returns values for known modules" do
      expect(described_class.all_for(:Validity)).to eq(%w[DAY IOC])
    end

    it "returns empty array for unknown modules" do
      expect(described_class.all_for(:UnknownThing)).to eq([])
    end
  end
end
