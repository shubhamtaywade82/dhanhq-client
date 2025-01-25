# frozen_string_literal: true

require "webmock/rspec"

RSpec.describe DhanHQ::BaseAPI do
  class TestAPI < DhanHQ::BaseAPI
    HTTP_PATH = "/test"
  end

  let(:api) { TestAPI.new }
  let(:client_id) { "test_client_id" }
  let(:access_token) { "test_access_token" }

  before do
    DhanHQ.configure do |config|
      config.client_id = client_id
      config.access_token = access_token
    end
  end

  describe "#resource_path" do
    it "returns the correct resource path" do
      expect(api.resource_path).to eq("/test")
    end
  end

  describe "#get" do
    it "sends a GET request and returns the parsed response" do
      stub_request(:get, "https://api.dhan.co/v2/test/endpoint")
        .with(
          headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          },
          query: { dhanClientId: client_id, param: "value" }
        )
        .to_return(status: 200, body: { status: "success", data: { key: "value" } }.to_json)

      response = api.get("/endpoint", params: { param: "value" })
      expect(response[:data]).to eq({ key: "value" })
    end

    it "raises an error for an unsuccessful GET request" do
      stub_request(:get, "https://api.dhan.co/v2/test/endpoint")
        .to_return(status: 400, body: { status: "error", message: "Invalid request" }.to_json)

      expect { api.get("/endpoint") }.to raise_error(DhanHQ::ApiError, "Invalid request")
    end
  end

  describe "#post" do
    it "sends a POST request and returns the parsed response" do
      stub_request(:post, "https://api.dhan.co/v2/test/endpoint")
        .with(
          headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          },
          body: { dhanClientId: client_id, param: "value" }.to_json
        )
        .to_return(status: 200, body: { status: "success", data: { key: "value" } }.to_json)

      response = api.post("/endpoint", params: { param: "value" })
      expect(response[:data]).to eq({ key: "value" })
    end

    it "raises an error for an unsuccessful POST request" do
      stub_request(:post, "https://api.dhan.co/v2/test/endpoint")
        .to_return(status: 422, body: { status: "error", message: "Validation failed" }.to_json)

      expect { api.post("/endpoint", params: { param: "value" }) }.to raise_error(DhanHQ::ApiError, "Validation failed")
    end
  end

  describe "#put" do
    it "sends a PUT request and returns the parsed response" do
      stub_request(:put, "https://api.dhan.co/v2/test/endpoint")
        .with(
          headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          },
          body: { dhanClientId: client_id, param: "value" }.to_json
        )
        .to_return(status: 200, body: { status: "success", data: { key: "updated_value" } }.to_json)

      response = api.put("/endpoint", params: { param: "value" })
      expect(response[:data]).to eq({ key: "updated_value" })
    end

    it "raises an error for an unsuccessful PUT request" do
      stub_request(:put, "https://api.dhan.co/v2/test/endpoint")
        .to_return(status: 404, body: { status: "error", message: "Not found" }.to_json)

      expect { api.put("/endpoint", params: { param: "value" }) }.to raise_error(DhanHQ::ApiError, "Not found")
    end
  end

  describe "#delete" do
    it "sends a DELETE request and returns the parsed response" do
      stub_request(:delete, "https://api.dhan.co/v2/test/endpoint")
        .with(
          headers: {
            "Content-Type" => "application/json",
            "Authorization" => "Bearer #{access_token}"
          },
          query: { dhanClientId: client_id }
        )
        .to_return(status: 200, body: { status: "success" }.to_json)

      response = api.delete("/endpoint")
      expect(response[:status]).to eq("success")
    end

    it "raises an error for an unsuccessful DELETE request" do
      stub_request(:delete, "https://api.dhan.co/v2/test/endpoint")
        .to_return(status: 403, body: { status: "error", message: "Forbidden" }.to_json)

      expect { api.delete("/endpoint") }.to raise_error(DhanHQ::ApiError, "Forbidden")
    end
  end

  describe "error handling" do
    it "handles generic errors" do
      allow(api).to receive(:perform_request).and_raise(StandardError.new("Unexpected error"))
      expect { api.get("/endpoint") }.to raise_error(DhanHQ::ApiError, "Unexpected error")
    end

    it "raises a DhanHQ::ApiError for HTTP request errors" do
      stub_request(:get, "https://api.dhan.co/v2/test/endpoint")
        .to_return(status: 500, body: { status: "error", message: "Internal server error" }.to_json)

      expect { api.get("/endpoint") }.to raise_error(DhanHQ::ApiError, "Internal server error")
    end
  end
end
