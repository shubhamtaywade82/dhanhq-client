# frozen_string_literal: true

RSpec.describe DhanHQ::ErrorObject do
  subject(:error_object) { described_class.new(response) }

  let(:response) do
    {
      status: "error",
      errorCode: "DH-905",
      errorMessage: "Something went wrong"
    }
  end

  it "exposes the raw response" do
    expect(error_object.response).to include(status: "error")
  end

  it "returns false for success?" do
    expect(error_object.success?).to be false
  end

  it "provides the error message" do
    expect(error_object.message).to eq("Something went wrong")
  end

  it "provides the error code" do
    expect(error_object.code).to eq("DH-905")
  end
end
