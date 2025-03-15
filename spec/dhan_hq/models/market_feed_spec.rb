# frozen_string_literal: true

RSpec.describe DhanHQ::Models::MarketFeed, vcr: {
  cassette_name: "models/market_feed",
  record: :new_episodes # :once  # or :new_episodes, etc. based on your preference
} do
  before do
    # Ensure the DhanHQ gem is configured with valid credentials.
    # This pulls from ENV["CLIENT_ID"] and ENV["ACCESS_TOKEN"], for example.
    DhanHQ.configure_with_env
  end

  describe ".ltp" do
    let(:params) do
      {
        # Example structure for LTP.
        # Each key is an exchange segment, array of security IDs to get LTP
        "NSE_EQ" => [11_536, 1333],
        "BSE_EQ" => [49_081, 49_082]
      }
    end

    it "retrieves last traded prices for the specified instruments" do
      response = described_class.ltp(params)

      expect(response).to be_a(Hash)
      expect(response[:data]).to be_a(Hash)

      # e.g. response might look like:
      # {
      #   data: {
      #     NSE_EQ: { 1333 => { last_price: 1234.5 } },
      #     BSE_EQ: { 532540 => { last_price: 234.5 } }
      #   },
      #   status: "success"
      # }

      # Verify structure:
      expect(response[:status]).to eq("success")
      expect(response[:data].keys).to include("NSE_EQ", "BSE_EQ")

      nse_eq_data = response[:data]["NSE_EQ"]
      expect(nse_eq_data).to be_a(Hash)

      # For each securityId, you can check :last_price is a Float
      nse_eq_data.each do |sec_id, sec_data|
        expect(sec_id).to be_a(String).or be_a(Integer)
        expect(sec_data).to include(:last_price)
        expect(sec_data[:last_price]).to be_a(Float)
      end
    end
  end

  describe ".ohlc" do
    let(:params) do
      {
        "NSE_EQ" => [1333]
      }
    end

    it "retrieves OHLC data for the specified instruments" do
      response = described_class.ohlc(params)

      expect(response).to be_a(Hash)
      expect(response[:status]).to eq("success")
      expect(response[:data]).to be_a(Hash)

      # e.g. response[:data] => {
      #   "NSE_EQ" => {
      #       "11536" => { last_price: 4525.55, ohlc: {...} },
      #   }
      # }
      expect(response[:status]).to eq("success")
      expect(response[:data].keys).to include("NSE_EQ")

      nse_eq_data = response[:data]["NSE_EQ"]
      expect(nse_eq_data).to be_a(Hash)

      # data = response[:data]["NSE_EQ"]["11536"]
      # expect(data[:last_price]).to be_a(Float)
      # expect(data[:ohlc]).to be_a(Hash)
      # expect(data[:ohlc][:open]).to be_a(Float)
      # expect(data[:ohlc][:close]).to be_a(Float)
      # expect(data[:ohlc][:high]).to be_a(Float)
      # expect(data[:ohlc][:low]).to be_a(Float)
    end
  end

  describe ".quote" do
    let(:params) do
      {
        "NSE_FNO" => [49_081, 49_082]
      }
    end

    it "retrieves market depth and quote data for the specified instruments" do
      response = described_class.quote(params)

      expect(response).to be_a(Hash)
      expect(response[:status]).to eq("success")
      expect(response[:data]).to be_a(Hash)

      # e.g. response[:data][:NSE_FNO][:49081] => {
      #   average_price: 0.0,
      #   buy_quantity: 1825,
      #   depth: { buy: [...], sell: [...] },
      #   ...
      # }

      expect(response[:data].keys).to include("NSE_FNO")
      # nse_fno_data = response[:data]["NSE_FNO"]["49081"]
      # expect(nse_fno_data[:average_price]).to be_a(Float)
      # expect(nse_fno_data[:last_price]).to be_a(Float)
      # expect(nse_fno_data[:depth]).to be_a(Hash)

      # # Check buy/sell depths
      # buy_depth = nse_fno_data[:depth][:buy]
      # expect(buy_depth).to be_an(Array)
      # first_bid = buy_depth.first
      # expect(first_bid).to include(:quantity, :price)
    end
  end
end
