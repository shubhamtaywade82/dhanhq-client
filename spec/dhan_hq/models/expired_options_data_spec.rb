# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Models::ExpiredOptionsData do
  let(:valid_params) do
    {
      exchange_segment: "NSE_FNO",
      interval: "1",
      security_id: 13,
      instrument: "OPTIDX",
      expiry_flag: "MONTH",
      expiry_code: 1,
      strike: "ATM",
      drv_option_type: "CALL",
      required_data: %w[open high low close volume],
      from_date: "2021-08-01",
      to_date: "2021-08-30"
    }
  end

  let(:sample_response) do
    {
      data: {
        "ce" => {
          "iv" => [0.25, 0.26],
          "oi" => [1000, 1200],
          "strike" => [18_000, 18_000],
          "spot" => [18_000, 18_050],
          "open" => [354, 360.3],
          "high" => [358, 365],
          "low" => [352, 358],
          "close" => [356, 362],
          "volume" => [100, 150],
          "timestamp" => [1_756_698_300, 1_756_699_200]
        },
        "pe" => nil
      }
    }
  end

  describe ".fetch" do
    let(:expired_options_resource) { instance_double(DhanHQ::Resources::ExpiredOptionsData) }

    before do
      allow(DhanHQ::Resources::ExpiredOptionsData).to receive(:new).and_return(expired_options_resource)
      allow(expired_options_resource).to receive(:fetch).and_return(sample_response)
    end

    it "fetches expired options data with valid parameters" do
      result = described_class.fetch(valid_params)

      expect(result).to be_a(described_class)
      expect(result.exchange_segment).to eq("NSE_FNO")
      expect(result.instrument).to eq("OPTIDX")
      expect(result.strike).to eq("ATM")
      expect(result.drv_option_type).to eq("CALL")
    end

    it "validates parameters before making API call" do
      invalid_params = valid_params.merge(interval: "99")

      expect { described_class.fetch(invalid_params) }
        .to raise_error(DhanHQ::ValidationError, /Invalid parameters/)
    end

    it "validates date range" do
      invalid_params = valid_params.merge(from_date: "2021-09-01", to_date: "2021-08-01")

      expect { described_class.fetch(invalid_params) }
        .to raise_error(DhanHQ::ValidationError, /from_date must be on or before to_date/)
    end

    it "validates date range length" do
      invalid_params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-09-15")

      expect { described_class.fetch(invalid_params) }
        .to raise_error(DhanHQ::ValidationError, /date range cannot exceed 31 days/)
    end

    it "validates required data fields" do
      invalid_params = valid_params.merge(required_data: %w[invalid_field])

      expect { described_class.fetch(invalid_params) }
        .to raise_error(DhanHQ::ValidationError, /contains invalid data types/)
    end
  end

  describe "data access methods" do
    let(:expired_options_data) do
      described_class.new(sample_response.merge(valid_params), skip_validation: true)
    end

    describe "#call_data" do
      it "returns call option data" do
        call_data = expired_options_data.call_data

        expect(call_data).to be_a(Hash)
        expect(call_data["open"]).to eq([354, 360.3])
        expect(call_data["volume"]).to eq([100, 150])
      end
    end

    describe "#put_data" do
      it "returns put option data" do
        put_data = expired_options_data.put_data

        expect(put_data).to be_nil
      end
    end

    describe "#data_for_type" do
      it "returns call data for CALL option type" do
        data = expired_options_data.data_for_type("CALL")

        expect(data).to be_a(Hash)
        expect(data["open"]).to eq([354, 360.3])
      end

      it "returns put data for PUT option type" do
        data = expired_options_data.data_for_type("PUT")

        expect(data).to be_nil
      end

      it "returns nil for invalid option type" do
        data = expired_options_data.data_for_type("INVALID")

        expect(data).to be_nil
      end
    end

    describe "#ohlc_data" do
      it "returns OHLC data for call options" do
        ohlc = expired_options_data.ohlc_data("CALL")

        expect(ohlc).to include(
          open: [354, 360.3],
          high: [358, 365],
          low: [352, 358],
          close: [356, 362]
        )
      end

      it "uses default option type when not specified" do
        ohlc = expired_options_data.ohlc_data

        expect(ohlc[:open]).to eq([354, 360.3])
      end
    end

    describe "#volume_data" do
      it "returns volume data" do
        volume = expired_options_data.volume_data("CALL")

        expect(volume).to eq([100, 150])
      end
    end

    describe "#open_interest_data" do
      it "returns open interest data" do
        oi = expired_options_data.open_interest_data("CALL")

        expect(oi).to eq([1000, 1200])
      end
    end

    describe "#implied_volatility_data" do
      it "returns implied volatility data" do
        iv = expired_options_data.implied_volatility_data("CALL")

        expect(iv).to eq([0.25, 0.26])
      end
    end

    describe "#strike_data" do
      it "returns strike data" do
        strikes = expired_options_data.strike_data("CALL")

        expect(strikes).to eq([18_000, 18_000])
      end
    end

    describe "#spot_data" do
      it "returns spot data" do
        spots = expired_options_data.spot_data("CALL")

        expect(spots).to eq([18_000, 18_050])
      end
    end

    describe "#timestamp_data" do
      it "returns timestamp data" do
        timestamps = expired_options_data.timestamp_data("CALL")

        expect(timestamps).to eq([1_756_698_300, 1_756_699_200])
      end
    end
  end

  describe "calculation methods" do
    let(:expired_options_data) do
      described_class.new(sample_response.merge(valid_params), skip_validation: true)
    end

    describe "#data_points_count" do
      it "returns number of data points" do
        count = expired_options_data.data_points_count("CALL")

        expect(count).to eq(2)
      end
    end

    describe "#average_volume" do
      it "calculates average volume" do
        avg_volume = expired_options_data.average_volume("CALL")

        expect(avg_volume).to eq(125.0) # (100 + 150) / 2
      end

      it "returns 0 for empty volume data" do
        empty_data = { data: { "ce" => { "volume" => [] } } }
        expired_options = described_class.new(empty_data.merge(valid_params), skip_validation: true)

        expect(expired_options.average_volume("CALL")).to eq(0.0)
      end
    end

    describe "#average_open_interest" do
      it "calculates average open interest" do
        avg_oi = expired_options_data.average_open_interest("CALL")

        expect(avg_oi).to eq(1100.0) # (1000 + 1200) / 2
      end
    end

    describe "#average_implied_volatility" do
      it "calculates average implied volatility" do
        avg_iv = expired_options_data.average_implied_volatility("CALL")

        expect(avg_iv).to eq(0.255) # (0.25 + 0.26) / 2
      end
    end

    describe "#price_ranges" do
      it "calculates price ranges" do
        ranges = expired_options_data.price_ranges("CALL")

        expect(ranges).to eq([6, 7]) # [358-352, 365-358]
      end
    end

    describe "#summary_stats" do
      it "provides comprehensive summary statistics" do
        stats = expired_options_data.summary_stats("CALL")

        expect(stats).to include(
          data_points: 2,
          avg_volume: 125.0,
          avg_open_interest: 1100.0,
          avg_implied_volatility: 0.255,
          price_ranges: [6, 7],
          has_ohlc: true,
          has_volume: true,
          has_open_interest: true,
          has_implied_volatility: true
        )
      end
    end
  end

  describe "helper methods" do
    let(:expired_options_data) do
      described_class.new(sample_response.merge(valid_params), skip_validation: true)
    end

    describe "#index_options?" do
      it "returns true for index options" do
        expect(expired_options_data.index_options?).to be true
      end

      it "returns false for stock options" do
        stock_params = valid_params.merge(instrument: "OPTSTK")
        stock_data = described_class.new(sample_response.merge(stock_params), skip_validation: true)

        expect(stock_data.index_options?).to be false
      end
    end

    describe "#stock_options?" do
      it "returns true for stock options" do
        stock_params = valid_params.merge(instrument: "OPTSTK")
        stock_data = described_class.new(sample_response.merge(stock_params), skip_validation: true)

        expect(stock_data.stock_options?).to be true
      end

      it "returns false for index options" do
        expect(expired_options_data.stock_options?).to be false
      end
    end

    describe "#weekly_expiry?" do
      it "returns true for weekly expiry" do
        weekly_params = valid_params.merge(expiry_flag: "WEEK")
        weekly_data = described_class.new(sample_response.merge(weekly_params), skip_validation: true)

        expect(weekly_data.weekly_expiry?).to be true
      end

      it "returns false for monthly expiry" do
        expect(expired_options_data.weekly_expiry?).to be false
      end
    end

    describe "#monthly_expiry?" do
      it "returns true for monthly expiry" do
        expect(expired_options_data.monthly_expiry?).to be true
      end

      it "returns false for weekly expiry" do
        weekly_params = valid_params.merge(expiry_flag: "WEEK")
        weekly_data = described_class.new(sample_response.merge(weekly_params), skip_validation: true)

        expect(weekly_data.monthly_expiry?).to be false
      end
    end

    describe "#call_option?" do
      it "returns true for call options" do
        expect(expired_options_data.call_option?).to be true
      end

      it "returns false for put options" do
        put_params = valid_params.merge(drv_option_type: "PUT")
        put_data = described_class.new(sample_response.merge(put_params), skip_validation: true)

        expect(put_data.call_option?).to be false
      end
    end

    describe "#put_option?" do
      it "returns true for put options" do
        put_params = valid_params.merge(drv_option_type: "PUT")
        put_data = described_class.new(sample_response.merge(put_params), skip_validation: true)

        expect(put_data.put_option?).to be true
      end

      it "returns false for call options" do
        expect(expired_options_data.put_option?).to be false
      end
    end

    describe "#at_the_money?" do
      it "returns true for ATM strike" do
        expect(expired_options_data.at_the_money?).to be true
      end

      it "returns false for non-ATM strikes" do
        atm_plus_params = valid_params.merge(strike: "ATM+1")
        atm_plus_data = described_class.new(sample_response.merge(atm_plus_params), skip_validation: true)

        expect(atm_plus_data.at_the_money?).to be false
      end
    end

    describe "#strike_offset" do
      it "returns 0 for ATM strike" do
        expect(expired_options_data.strike_offset).to eq(0)
      end

      it "returns positive offset for ATM+X strikes" do
        atm_plus_params = valid_params.merge(strike: "ATM+5")
        atm_plus_data = described_class.new(sample_response.merge(atm_plus_params), skip_validation: true)

        expect(atm_plus_data.strike_offset).to eq(5)
      end

      it "returns negative offset for ATM-X strikes" do
        atm_minus_params = valid_params.merge(strike: "ATM-3")
        atm_minus_data = described_class.new(sample_response.merge(atm_minus_params), skip_validation: true)

        expect(atm_minus_data.strike_offset).to eq(-3)
      end
    end
  end

  describe "validation contract integration" do
    let(:contract) { DhanHQ::Contracts::ExpiredOptionsDataContract.new }

    it "validates exchange segment" do
      invalid_params = valid_params.merge(exchange_segment: "INVALID")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:exchange_segment]).to include(/must be one of/)
    end

    it "validates interval" do
      invalid_params = valid_params.merge(interval: "99")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:interval]).to include(/must be one of/)
    end

    it "validates instrument" do
      invalid_params = valid_params.merge(instrument: "INVALID")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:instrument]).to include(/must be one of/)
    end

    it "validates expiry flag" do
      invalid_params = valid_params.merge(expiry_flag: "INVALID")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:expiry_flag]).to include(/must be one of/)
    end

    it "validates strike format" do
      invalid_params = valid_params.merge(strike: "INVALID")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:strike]).to include(/must be in format ATM/)
    end

    it "validates option type" do
      invalid_params = valid_params.merge(drv_option_type: "INVALID")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:drv_option_type]).to include(/must be one of/)
    end

    it "validates date format" do
      invalid_params = valid_params.merge(from_date: "invalid-date")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/must be in YYYY-MM-DD format/)
    end

    it "validates date range" do
      invalid_params = valid_params.merge(from_date: "2021-09-01", to_date: "2021-08-01")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/from_date must be on or before to_date/)
    end

    it "validates date range length" do
      invalid_params = valid_params.merge(from_date: "2021-08-01", to_date: "2021-09-15")
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/date range cannot exceed 31 days/)
    end

    it "validates historical date limit" do
      old_date = (Date.today - (6 * 365)).strftime("%Y-%m-%d")
      invalid_params = valid_params.merge(from_date: old_date)
      result = contract.call(invalid_params)

      expect(result.failure?).to be true
      expect(result.errors[:from_date]).to include(/from_date cannot be more than 5 years ago/)
    end
  end
end
