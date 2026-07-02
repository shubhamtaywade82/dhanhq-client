# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Builtin::BuyAtmCall do
  let(:instrument) do
    double("instrument",
           ltp: { ltp: 24_500.0 },
           option_chain: [
             { strike: 24_400, option_type: "CE", security_id: "SEC001", last_price: 150.0 },
             { strike: 24_500, option_type: "CE", security_id: "SEC002", last_price: 100.0 },
             { strike: 24_600, option_type: "CE", security_id: "SEC003", last_price: 60.0 },
             { strike: 24_500, option_type: "PE", security_id: "SEC004", last_price: 90.0 }
           ])
  end

  before do
    allow(DhanHQ::Models::Instrument).to receive(:find).and_return(instrument)
  end

  describe "parameter definitions" do
    it "requires symbol and expiry" do
      params = described_class.params
      expect(params[:symbol][:required]).to be true
      expect(params[:expiry][:required]).to be true
    end

    it "has defaults for quantity, stop_loss, target" do
      params = described_class.params
      expect(params[:quantity][:default]).to eq(50)
      expect(params[:stop_loss][:default]).to eq(100)
      expect(params[:target][:default]).to eq(200)
    end
  end

  describe "#call" do
    it "finds instrument on IDX_I exchange" do
      described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(DhanHQ::Models::Instrument).to have_received(:find).with("IDX_I", "NIFTY")
    end

    it "fetches spot price from instrument ltp" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(result[:spot_price]).to eq(24_500.0)
    end

    it "fetches option chain with expiry" do
      described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(instrument).to have_received(:option_chain).with(expiry: "2026-01-30")
    end

    it "selects ATM CE strike closest to spot" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      expect(result[:selected_option][:strike]).to eq(24_500)
      expect(result[:selected_option][:option_type]).to eq("CE")
    end

    it "builds trade intent with correct fields" do
      result = described_class.new.call(symbol: "NIFTY", expiry: "2026-01-30")
      intent = result[:intent]

      expect(intent[:trade_type]).to eq("OPTIONS_BUY")
      expect(intent[:instrument]).to eq("NIFTY 24500 CE")
      expect(intent[:security_id]).to eq("SEC002")
      expect(intent[:strike]).to eq(24_500)
      expect(intent[:expiry]).to eq("2026-01-30")
      expect(intent[:option_type]).to eq("CE")
      expect(intent[:quantity]).to eq(50)
      expect(intent[:premium]).to eq(100.0)
      expect(intent[:stop_loss]).to eq(100)
      expect(intent[:target]).to eq(200)
      expect(intent[:note]).to include("Await human confirmation")
    end

    it "accepts custom quantity, stop_loss, target" do
      result = described_class.new.call(
        symbol: "NIFTY",
        expiry: "2026-01-30",
        quantity: 75,
        stop_loss: 150,
        target: 300
      )
      intent = result[:intent]

      expect(intent[:quantity]).to eq(75)
      expect(intent[:stop_loss]).to eq(150)
      expect(intent[:target]).to eq(300)
    end

    it "raises on missing symbol" do
      expect { described_class.new.call(expiry: "2026-01-30") }.to raise_error(ArgumentError, /symbol/)
    end

    it "raises on missing expiry" do
      expect { described_class.new.call(symbol: "NIFTY") }.to raise_error(ArgumentError, /expiry/)
    end
  end

  describe "#name" do
    it "returns class name" do
      expect(described_class.new.name).to include("BuyAtmCall")
    end
  end
end
