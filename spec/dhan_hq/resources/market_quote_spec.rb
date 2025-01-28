# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::MarketQuote do
  let(:market_quote) { described_class.new }

  let(:mock_ticker_response) do
    {
      data: {
        NSE_EQ: {
          "11536" => {
            last_price: 4520.0
          }
        },
        NSE_FNO: {
          "49081" => {
            last_price: 368.15
          },
          "49082" => {
            last_price: 694.35
          }
        }
      },
      status: "success"
    }.to_json
  end

  let(:mock_ohlc_response) do
    {
      data: {
        NSE_EQ: {
          "11536" => {
            last_price: 4525.55,
            ohlc: {
              open: 4521.45,
              close: 4507.85,
              high: 4530,
              low: 4500
            }
          }
        },
        NSE_FNO: {
          "49081" => {
            last_price: 368.15,
            ohlc: {
              open: 0,
              close: 368.15,
              high: 0,
              low: 0
            }
          }
        }
      },
      status: "success"
    }.to_json
  end

  let(:mock_market_depth_response) do
    {
      data: {
        NSE_FNO: {
          "49081" => {
            last_price: 368.15,
            buy_quantity: 1825,
            sell_quantity: 0,
            depth: {
              buy: [
                { quantity: 1800, orders: 1, price: 77 },
                { quantity: 25, orders: 1, price: 50 }
              ],
              sell: [
                { quantity: 0, orders: 0, price: 0 }
              ]
            }
          }
        }
      },
      status: "success"
    }.to_json
  end

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "header.payload.signature" # Mock JWT
      config.client_id = "test_client_id"
    end
    stub_request(:post, "https://api.dhan.co/v2/marketfeed/ltp")
      .to_return(
        status: 200,
        body: mock_ticker_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.dhan.co/v2/marketfeed/ohlc")
      .to_return(
        status: 200,
        body: mock_ohlc_response,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:post, "https://api.dhan.co/v2/marketfeed/quote")
      .to_return(
        status: 200,
        body: mock_market_depth_response,
        headers: { "Content-Type" => "application/json" }
      )
  end

  after { VCR.turn_on! }

  describe "#fetch_ticker_data" do
    it "fetches ticker data successfully" do
      params = {
        NSE_EQ: [11_536],
        NSE_FNO: [49_081, 49_082]
      }

      response = market_quote.fetch_ticker_data(params)
      expect(response["data"]["NSE_EQ"]["11536"]["last_price"]).to eq(4520.0)
      expect(response["data"]["NSE_FNO"]["49081"]["last_price"]).to eq(368.15)
    end
  end

  describe "#fetch_ohlc_data" do
    it "fetches OHLC data successfully" do
      params = {
        NSE_EQ: [11_536],
        NSE_FNO: [49_081]
      }

      response = market_quote.fetch_ohlc_data(params)
      expect(response["data"]["NSE_EQ"]["11536"]["ohlc"]["open"]).to eq(4521.45)
      expect(response["data"]["NSE_FNO"]["49081"]["ohlc"]["close"]).to eq(368.15)
    end
  end

  describe "#fetch_market_depth" do
    it "fetches market depth data successfully" do
      params = {
        NSE_FNO: [49_081]
      }

      response = market_quote.fetch_market_depth(params)
      expect(response["data"]["NSE_FNO"]["49081"]["last_price"]).to eq(368.15)
      expect(response["data"]["NSE_FNO"]["49081"]["depth"]["buy"].first["price"]).to eq(77)
    end
  end
end
