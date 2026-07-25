# frozen_string_literal: true

RSpec.describe DhanHQ::Models::MultiOrder do
  let(:url) { "https://api.dhan.co/v2/alerts/multi/orders" }

  let(:legs) do
    [
      { sequence: "1", transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
        order_type: "LIMIT", validity: "DAY", security_id: "11536", quantity: 1, price: 1500.0 },
      { sequence: "2", transaction_type: "BUY", exchange_segment: "NSE_EQ", product_type: "CNC",
        order_type: "MARKET", validity: "DAY", security_id: "1333", quantity: 2 }
    ]
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
    allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(nil)
    described_class.instance_variable_set(:@resource, nil)
    stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
  end

  after do
    DhanHQ::Utils::NetworkInspector.reset_cache!
    described_class.instance_variable_set(:@resource, nil)
  end

  describe ".place" do
    it "POSTs every leg and includes dhanClientId" do
      stub_request(:post, url)
        .to_return(status: 200,
                   body: { orders: [{ orderId: "1", sequence: "1", orderStatus: "TRANSIT" },
                                    { orderId: "2", sequence: "2", orderStatus: "TRANSIT" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = described_class.place(legs)

      expect(result.order_ids).to eq(%w[1 2])
      expect(result).to be_all_accepted
      expect(WebMock).to have_requested(:post, url)
        .with(body: hash_including("dhanClientId" => DhanHQ.configuration.client_id))
    end

    it "camelizes the nested leg fields, which the API requires" do
      stub_request(:post, url)
        .to_return(status: 200, body: { orders: [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      described_class.place(legs)

      expect(WebMock).to(have_requested(:post, url).with do |req|
        leg = JSON.parse(req.body)["orders"].first
        leg.key?("transactionType") && leg.key?("exchangeSegment") && leg.key?("securityId") &&
          leg.key?("productType") && leg.key?("orderType") &&
          %w[transaction_type exchange_segment security_id product_type order_type].none? { |k| leg.key?(k) }
      end)
    end

    it "preserves the caller's sequence on each leg" do
      stub_request(:post, url)
        .to_return(status: 200, body: { orders: [] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      described_class.place(legs)

      expect(WebMock).to(have_requested(:post, url).with do |req|
        JSON.parse(req.body)["orders"].map { |leg| leg["sequence"] } == %w[1 2]
      end)
    end

    it "accepts a bare array response" do
      stub_request(:post, url)
        .to_return(status: 200, body: [{ orderId: "1", sequence: "1", orderStatus: "TRANSIT" }].to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.place(legs.first(1)).order_ids).to eq(["1"])
    end

    it "surfaces partial acceptance" do
      stub_request(:post, url)
        .to_return(status: 200,
                   body: { orders: [{ orderId: "1", sequence: "1", orderStatus: "TRANSIT" },
                                    { sequence: "2", orderStatus: "REJECTED" }] }.to_json,
                   headers: { "Content-Type" => "application/json" })

      result = described_class.place(legs)

      expect(result).to be_partially_accepted
      expect(result).not_to be_all_accepted
      expect(result.rejected.map(&:sequence)).to eq(["2"])
      expect(result.for_sequence("1").order_id).to eq("1")
    end

    it "returns an ErrorObject when the response carries no legs" do
      stub_request(:post, url)
        .to_return(status: 200, body: { errorMessage: "nope" }.to_json,
                   headers: { "Content-Type" => "application/json" })

      expect(described_class.place(legs)).to be_a(DhanHQ::ErrorObject)
    end

    it "requires LIVE_TRADING" do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false"))

      expect { described_class.place(legs) }.to raise_error(DhanHQ::LiveTradingDisabledError)
    end
  end

  describe "validation" do
    it "rejects an empty basket" do
      expect { described_class.place([]) }.to raise_error(DhanHQ::ValidationError, /at least one order/)
    end

    it "rejects more than 15 legs" do
      too_many = (1..16).map { |i| legs.first.merge(sequence: i.to_s) }

      expect { described_class.place(too_many) }
        .to raise_error(DhanHQ::ValidationError, /more than 15/)
    end

    it "rejects duplicate sequence numbers" do
      expect { described_class.place([legs.first, legs.first]) }
        .to raise_error(DhanHQ::ValidationError, /unique/)
    end

    it "rejects a leg missing its sequence" do
      expect { described_class.place([legs.first.except(:sequence)]) }
        .to raise_error(DhanHQ::ValidationError, /sequence/)
    end

    it "rejects a LIMIT leg with no price" do
      expect { described_class.place([legs.first.except(:price)]) }
        .to raise_error(DhanHQ::ValidationError, /price/)
    end

    it "rejects a MARKET leg carrying a price" do
      expect { described_class.place([legs.last.merge(price: 100.0)]) }
        .to raise_error(DhanHQ::ValidationError, /MARKET/)
    end
  end

  describe "#to_prompt" do
    it "summarizes acceptance" do
      order = described_class.new(
        { orders: [{ orderId: "1", sequence: "1", orderStatus: "TRANSIT" },
                   { sequence: "2", orderStatus: "REJECTED" }] },
        skip_validation: true
      )

      expect(order.to_prompt).to eq("2 legs, 1 accepted, 1 rejected")
    end
  end
end
