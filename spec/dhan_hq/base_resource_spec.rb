# frozen_string_literal: true

RSpec.describe DhanHQ::BaseResource do
  let(:valid_attributes) do
    {
      dhanClientId: "12345",
      transactionType: "BUY",
      productType: "CNC",
      quantity: 10,
      price: 1500.0
    }
  end

  let(:invalid_attributes) do
    {
      dhanClientId: nil,
      transactionType: "INVALID_TYPE",
      quantity: -10,
      price: -100.0
    }
  end

  let(:mock_response) { { status: "success", data: valid_attributes } }
  let(:error_response) { { status: "error", message: "An error occurred" } }

  before do
    DhanHQ.configure do |config|
      config.base_url = "https://api.dhan.co/v2"
      config.access_token = "test_token"
      config.client_id = "test_client_id"
    end

    allow_any_instance_of(DhanHQ::Client).to receive(:get).and_return(mock_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:post).and_return(mock_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:put).and_return(mock_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:delete).and_return(mock_response)

    # Define attributes for the test class
    described_class.attributes :dhan_client_id, :transaction_type, :product_type, :quantity, :price

    allow_any_instance_of(described_class).to receive(:validation_contract).and_return(
      Class.new(Dry::Validation::Contract) do
        params do
          required(:dhanClientId).filled(:string)
          required(:transactionType).filled(:string)
          required(:productType).filled(:string)
          required(:quantity).filled(:integer, gt?: 0)
          required(:price).filled(:float, gt?: 0)
        end
      end.new
    )
  end

  describe ".initialize" do
    it "assigns attributes and validates successfully with valid data" do
      resource = described_class.new(valid_attributes)
      expect(resource.attributes).to include(valid_attributes.with_indifferent_access)
    end

    it "raises an error for invalid attributes" do
      expect { described_class.new(invalid_attributes) }.to raise_error(DhanHQ::Error, /Validation Error/)
    end
  end

  describe ".find" do
    it "fetches a resource by ID" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resource = described_class.find("123")
      expect(resource.attributes).to include(valid_attributes.with_indifferent_access)
    end
  end

  describe ".all" do
    let(:mock_all_response) do
      {
        status: "success",
        data: [
          {
            dhanClientId: "12345",
            transactionType: "BUY",
            productType: "CNC",
            quantity: 10,
            price: 1500.0
          },
          {
            dhanClientId: "67890",
            transactionType: "SELL",
            productType: "INTRADAY",
            quantity: 5,
            price: 1000.0
          }
        ]
      }
    end

    before do
      allow_any_instance_of(DhanHQ::Client).to receive(:get).and_return(mock_all_response)
    end

    it "fetches all resources" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resources = described_class.all

      # Check each resource is a valid instance of the class
      expect(resources).to all(be_a(described_class))

      # Verify attributes of the first resource
      expect(resources[0].attributes).to include(
        "dhanClientId" => "12345",
        "transactionType" => "BUY",
        "productType" => "CNC",
        "quantity" => 10,
        "price" => 1500.0
      )

      # Verify attributes of the second resource
      expect(resources[1].attributes).to include(
        "dhanClientId" => "67890",
        "transactionType" => "SELL",
        "productType" => "INTRADAY",
        "quantity" => 5,
        "price" => 1000.0
      )
    end
  end

  describe ".create" do
    it "creates a new resource" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resource = described_class.create(valid_attributes)
      expect(resource.attributes).to include(valid_attributes.with_indifferent_access)
    end
  end

  describe "#update" do
    it "updates a resource with new attributes" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")

      updated_response = {
        status: "success",
        data: valid_attributes.merge(price: 1600.0)
      }

      allow_any_instance_of(DhanHQ::Client).to receive(:put).and_return(updated_response)

      resource = described_class.new(valid_attributes)
      updated_resource = resource.update(price: 1600.0)

      expect(updated_resource.attributes[:price]).to eq(1600.0)
    end
  end

  describe "#delete" do
    it "deletes a resource and returns true on success" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resource = described_class.new(valid_attributes)
      expect(resource.delete).to be true
    end

    it "returns false if deletion fails" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      allow_any_instance_of(DhanHQ::Client).to receive(:delete).and_raise(StandardError)
      resource = described_class.new(valid_attributes)
      expect(resource.delete).to be false
    end
  end

  describe "#to_request_params" do
    it "converts snake_case keys to camelCase" do
      resource = described_class.new(valid_attributes)
      expect(resource.to_request_params).to eq(
        {
          "dhanClientId" => "12345",
          "transactionType" => "BUY",
          "productType" => "CNC",
          "quantity" => 10,
          "price" => 1500.0
        }
      )
    end
  end

  describe ".build_from_response" do
    it "returns a resource object for successful responses" do
      resource = described_class.build_from_response(mock_response)
      expect(resource).to be_a(described_class)
    end

    it "returns an error object for error responses" do
      error_object = described_class.build_from_response(error_response)
      expect(error_object).to be_a(DhanHQ::ErrorObject)
      expect(error_object.success?).to be false
    end
  end
end
