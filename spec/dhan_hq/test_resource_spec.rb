# frozen_string_literal: true

RSpec.describe DhanHQ::TestResource do
  let(:valid_attributes) do
    {
      dhanClientId: "1000000003",
      correlationId: "123abc678",
      transactionType: "BUY",
      exchangeSegment: "NSE_EQ",
      productType: "INTRADAY",
      orderType: "MARKET",
      validity: "DAY",
      securityId: "11536",
      quantity: 5,
      disclosedQuantity: nil,
      price: nil,
      triggerPrice: nil,
      afterMarketOrder: false,
      amoTime: nil,
      boProfitValue: nil,
      boStopLossValue: nil
    }
  end

  let(:api_response) { { status: "success", data: valid_attributes } }

  let(:update_response) do
    {
      status: "success",
      data: valid_attributes.merge(quantity: 10, price: 200.0)
    }
  end

  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.access_token = "test_access_token"
      config.client_id = "test_client_id"
    end
    allow_any_instance_of(DhanHQ::Client).to receive(:get).and_return(api_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:post).and_return(api_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:put).and_return(update_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:delete).and_return(api_response)
  end

  after { VCR.turn_on! }

  describe ".initialize" do
    it "creates a new resource with valid attributes" do
      resource = described_class.new(valid_attributes)

      expect(resource.attributes).to include(valid_attributes)
    end

    it "validates required attributes" do
      expect do
        described_class.new(valid_attributes.except(:transactionType))
      end.to raise_error(DhanHQ::Error, /Validation Error/)
    end
  end

  describe "attribute accessors" do
    it "allows access using snake_case keys" do
      resource = described_class.new(valid_attributes)

      expect(resource.dhan_client_id).to eq("1000000003")
    end

    it "allows access using camelCase keys" do
      resource = described_class.new(valid_attributes)
      expect(resource.dhanClientId).to eq("1000000003")
    end
  end

  describe ".find" do
    it "fetches a resource by ID" do
      resource = described_class.find("11536")
      expect(resource.attributes).to include(valid_attributes)
    end
  end

  describe ".create" do
    it "creates a new resource with snake_case and camelCase attributes" do
      resource = described_class.create(valid_attributes)
      expect(resource.attributes).to include(valid_attributes)
      expect(resource.dhan_client_id).to eq("1000000003")
      expect(resource.dhanClientId).to eq("1000000003")
    end
  end

  describe "#update" do
    it "updates a resource with new attributes" do
      resource = described_class.new(valid_attributes)
      updated_resource = resource.update(quantity: 10, price: 200.0)

      expect(updated_resource.attributes[:quantity]).to eq(10)
      expect(updated_resource.attributes[:price]).to eq(200.0)
    end
  end

  describe "#delete" do
    it "deletes the resource successfully" do
      resource = described_class.new(valid_attributes)
      expect(resource.delete).to be true
    end
  end

  describe "#to_request_params" do
    it "converts snake_case keys to camelCase for API requests" do
      resource = described_class.new(valid_attributes)
      expect(resource.to_request_params).to eq(
        {
          "dhanClientId" => "1000000003",
          "correlationId" => "123abc678",
          "transactionType" => "BUY",
          "exchangeSegment" => "NSE_EQ",
          "productType" => "INTRADAY",
          "orderType" => "MARKET",
          "validity" => "DAY",
          "securityId" => "11536",
          "quantity" => 5,
          "disclosedQuantity" => nil,
          "price" => nil,
          "triggerPrice" => nil,
          "afterMarketOrder" => false,
          "amoTime" => nil,
          "boProfitValue" => nil,
          "boStopLossValue" => nil
        }
      )
    end
  end
end
