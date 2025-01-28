# frozen_string_literal: true

RSpec.describe DhanHQ::BaseResource do
  let(:valid_attributes) do
    {
      dhanClientId: "12345",
      transactionType: DhanHQ::Constants::BUY,
      productType: DhanHQ::Constants::CNC,
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
    allow_any_instance_of(DhanHQ::Client).to receive(:get).and_return(mock_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:post).and_return(mock_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:put).and_return(mock_response)
    allow_any_instance_of(DhanHQ::Client).to receive(:delete).and_return(mock_response)
  end

  describe ".initialize" do
    it "assigns attributes and validates successfully with valid data" do
      resource = described_class.new(valid_attributes)
      expect(resource.attributes).to eq(valid_attributes)
    end

    it "raises an error for invalid attributes" do
      allow_any_instance_of(described_class).to receive(:validation_contract).and_return(nil)
      expect { described_class.new(invalid_attributes) }.to raise_error(DhanHQ::Error, /Validation Error/)
    end
  end

  describe ".find" do
    it "fetches a resource by ID" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resource = described_class.find("123")
      expect(resource.attributes).to eq(valid_attributes)
    end
  end

  describe ".all" do
    it "fetches all resources" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resources = described_class.all
      expect(resources).to all(be_a(described_class))
    end
  end

  describe ".create" do
    it "creates a new resource" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
      resource = described_class.create(valid_attributes)
      expect(resource.attributes).to eq(valid_attributes)
    end
  end

  describe "#update" do
    it "updates a resource with new attributes" do
      allow(described_class).to receive(:resource_path).and_return("/test_resource")
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

  describe "#valid?" do
    it "returns true for valid attributes" do
      resource = described_class.new(valid_attributes)
      expect(resource.valid?).to be true
    end

    it "returns false for invalid attributes" do
      allow_any_instance_of(described_class).to receive(:validation_contract).and_return(nil)
      resource = described_class.new(valid_attributes.merge(transactionType: "INVALID"))
      expect(resource.valid?).to be false
    end
  end

  describe "#to_request_params" do
    it "converts snake_case keys to camelCase" do
      resource = described_class.new(valid_attributes)
      camelized_params = resource.to_request_params
      expect(camelized_params).to eq({
                                       "dhanClientId" => "12345",
                                       "transactionType" => "BUY",
                                       "productType" => "CNC",
                                       "quantity" => 10,
                                       "price" => 1500.0
                                     })
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
