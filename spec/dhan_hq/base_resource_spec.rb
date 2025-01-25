# frozen_string_literal: true

RSpec.describe DhanHQ::BaseResource do
  class TestResource < DhanHQ::BaseResource
    private

    def validation_contract
      Dry::Validation.Contract do
        params do
          required(:name).filled(:string)
        end
      end
    end
  end

  it "validates attributes correctly" do
    resource = TestResource.new(name: "Test")
    expect(resource.valid?).to be true
  end

  it "returns errors for invalid attributes" do
    resource = TestResource.new(name: nil)
    expect(resource.valid?).to be false
    expect(resource.errors).to include(:name)
  end
end
