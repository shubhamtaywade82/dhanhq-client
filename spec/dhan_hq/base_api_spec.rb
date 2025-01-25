# frozen_string_literal: true

require "webmock/rspec"
require "json"

RSpec.describe DhanHQ::BaseAPI do
  before do
    VCR.turn_off!
    DhanHQ.configure do |config|
      config.access_token = "test_access_token"
      config.client_id = "test_client_id"
    end
  end

  after { VCR.turn_on! }

  let(:api) { DhanHQ::TestAPI.new }
  let(:test_params) { { param1: "value1", param2: "value2", dhanClientId: "test_client_id" } }
  let(:base_url) { DhanHQ.configuration.base_url.chomp("/") }
  let(:headers) do
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json",
      "access-token" => "test_access_token",
      "User-Agent" => "Faraday v1.10.4",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3" # Include this
    }
  end

  def stub_response(file_name, status, method, endpoint, body = nil)
    response = File.read(File.join("spec/support/stubs", file_name))
    stub_request(method, "#{base_url}#{endpoint}")
      .with(
        body: body&.to_json,
        headers: headers
      )
      .to_return(status: status, body: response, headers: {})
  end

  describe "GET requests" do
    it "sends a GET request and returns the response" do
      stub_response("get_success.json", 200, :get, "/test/123")

      response = api.get("/123")
      expect(response).to include("status" => "success")
      expect(response["data"]).to include("id" => 123)
    end

    it "handles errors for GET requests" do
      stub_response("error_response.json", 404, :get, "/test/123")

      expect { api.get("/123") }.to raise_error(DhanHQ::ApiError, /Not Found/)
    end
  end

  describe "POST requests" do
    it "sends a POST request and returns the response" do
      stub_response("post_success.json", 200, :post, "/test", test_params)

      response = api.fetch(test_params)
      expect(response).to include("status" => "success")
    end

    it "handles errors for POST requests" do
      stub_response("error_response.json", 404, :post, "/test", test_params)

      expect { api.fetch(test_params) }.to raise_error(DhanHQ::ApiError, /Not Found/)
    end
  end

  describe "PUT requests" do
    it "sends a PUT request and returns the response" do
      stub_response("put_success.json", 200, :put, "/test/123", test_params)

      response = api.update("123", test_params)
      expect(response).to include("status" => "success")
    end

    it "handles errors for PUT requests" do
      stub_response("error_response.json", 400, :put, "/test/123", test_params)

      expect { api.update("123", test_params) }.to raise_error(DhanHQ::ApiError, /Not Found/)
    end
  end

  describe "DELETE requests" do
    it "sends a DELETE request and returns the response" do
      stub_response("delete_success.json", 200, :delete, "/test/123", { dhanClientId: "test_client_id" })

      response = api.delete("/123")
      expect(response).to include("status" => "success")
    end

    it "handles errors for DELETE requests" do
      stub_response("error_response.json", 404, :delete, "/test/123", { dhanClientId: "test_client_id" })

      expect { api.delete("/123") }.to raise_error(DhanHQ::ApiError, /Not Found/)
    end
  end

  describe "Error handling" do
    it "raises an error for unexpected server errors" do
      stub_response("internal_error_response.json", 500, :get, "/test/123")

      expect { api.get("/123") }.to raise_error(DhanHQ::ApiError, /Internal Server Error/)
    end
  end
end
