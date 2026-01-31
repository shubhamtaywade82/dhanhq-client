# frozen_string_literal: true

require "dhan_hq"

RSpec.describe DhanHQ::Configuration do
  let(:config) { described_class.new }

  # Store original ENV values for this spec
  before(:all) do
    @original_client_id = ENV.fetch("CLIENT_ID", nil)
    @original_access_token = ENV.fetch("ACCESS_TOKEN", nil)
  end

  after do
    # Restore original ENV values instead of deleting
    if @original_client_id
      ENV["CLIENT_ID"] = @original_client_id
    else
      ENV.delete("CLIENT_ID")
    end
    if @original_access_token
      ENV["ACCESS_TOKEN"] = @original_access_token
    else
      ENV.delete("ACCESS_TOKEN")
    end
  end

  describe "#initialize" do
    before do
      ENV.delete("ACCESS_TOKEN")
      ENV.delete("CLIENT_ID")
    end

    it "sets default values" do
      expect(config.base_url).to eq("https://api.dhan.co/v2")
      expect(config.access_token).to be_nil
      expect(config.client_id).to be_nil
    end

    it "loads access_token and client_id from ENV if present" do
      ENV["ACCESS_TOKEN"] = "env_access_token"
      ENV["CLIENT_ID"] = "env_client_id"

      config_with_env = described_class.new

      expect(config_with_env.access_token).to eq("env_access_token")
      expect(config_with_env.client_id).to eq("env_client_id")
    end
  end

  describe ".configure_with_env" do
    before do
      ENV["ACCESS_TOKEN"] = "env_access_token"
      ENV["CLIENT_ID"] = "env_client_id"
    end

    it "configures access_token and client_id from environment variables" do
      DhanHQ.configure_with_env

      expect(DhanHQ.configuration.access_token).to eq("env_access_token")
      expect(DhanHQ.configuration.client_id).to eq("env_client_id")
    end
  end

  describe ".configure" do
    it "allows manual configuration with a block" do
      DhanHQ.configure do |config|
        config.access_token = "block_access_token"
        config.client_id = "block_client_id"
      end

      expect(DhanHQ.configuration.access_token).to eq("block_access_token")
      expect(DhanHQ.configuration.client_id).to eq("block_client_id")
    end

    it "updates configuration multiple times without conflicts" do
      DhanHQ.configure do |config|
        config.access_token = "first_token"
      end

      DhanHQ.configure do |config|
        config.client_id = "updated_client_id"
      end

      expect(DhanHQ.configuration.access_token).to eq("first_token")
      expect(DhanHQ.configuration.client_id).to eq("updated_client_id")
    end
  end

  describe "#resolved_access_token" do
    it "uses access_token_provider if present" do
      config = described_class.new
      config.access_token_provider = -> { "dynamic-token" }

      expect(config.resolved_access_token).to eq("dynamic-token")
    end

    it "falls back to static access_token when provider is not set" do
      config = described_class.new
      config.access_token = "static-token"

      expect(config.resolved_access_token).to eq("static-token")
    end

    it "raises AuthenticationError if provider returns nil" do
      config = described_class.new
      config.access_token_provider = -> {}

      expect { config.resolved_access_token }.to raise_error(DhanHQ::AuthenticationError)
    end

    it "raises AuthenticationError if provider returns empty string" do
      config = described_class.new
      config.access_token_provider = -> { "" }

      expect { config.resolved_access_token }.to raise_error(DhanHQ::AuthenticationError)
    end
  end

  describe "Custom URLs" do
    it "allows setting custom compact and detailed CSV URLs" do
      config.compact_csv_url = "https://custom.compact.csv"
      config.detailed_csv_url = "https://custom.detailed.csv"

      expect(config.compact_csv_url).to eq("https://custom.compact.csv")
      expect(config.detailed_csv_url).to eq("https://custom.detailed.csv")
    end
  end

  describe ".configure_from_token_endpoint" do
    let(:token_url) { "https://myapp.com/auth/dhan/token" }
    let(:bearer_token) { "secret-token-to-access-access-token" }

    before do
      DhanHQ.configuration = nil
    end

    context "when endpoint returns 200 with access_token and client_id" do
      before do
        stub_request(:get, token_url)
          .with(headers: { "Authorization" => "Bearer #{bearer_token}", "Accept" => "application/json" })
          .to_return(status: 200, body: { access_token: "fetched_token", client_id: "fetched_client_id" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "sets configuration from the token endpoint response" do
        result = DhanHQ.configure_from_token_endpoint(base_url: "https://myapp.com", bearer_token: bearer_token)

        expect(result).to eq(DhanHQ.configuration)
        expect(DhanHQ.configuration.access_token).to eq("fetched_token")
        expect(DhanHQ.configuration.client_id).to eq("fetched_client_id")
      end

      it "optionally sets base_url when present in response" do
        stub_request(:get, token_url)
          .with(headers: { "Authorization" => "Bearer #{bearer_token}", "Accept" => "application/json" })
          .to_return(status: 200, body: { access_token: "t", client_id: "c", base_url: "https://custom.dhan.co/v2" }.to_json, headers: { "Content-Type" => "application/json" })

        DhanHQ.configure_from_token_endpoint(base_url: "https://myapp.com", bearer_token: bearer_token)

        expect(DhanHQ.configuration.base_url).to eq("https://custom.dhan.co/v2")
      end
    end

    context "when base_url or bearer_token are missing" do
      it "raises TokenEndpointError when base_url is empty" do
        expect { DhanHQ.configure_from_token_endpoint(base_url: "", bearer_token: "x") }
          .to raise_error(DhanHQ::TokenEndpointError, /base_url and bearer_token.*required/)
      end

      it "raises TokenEndpointError when bearer_token is empty" do
        expect { DhanHQ.configure_from_token_endpoint(base_url: "https://myapp.com", bearer_token: "") }
          .to raise_error(DhanHQ::TokenEndpointError, /base_url and bearer_token.*required/)
      end
    end

    context "when endpoint returns non-2xx" do
      before do
        stub_request(:get, token_url)
          .with(headers: { "Authorization" => "Bearer #{bearer_token}", "Accept" => "application/json" })
          .to_return(status: 401, body: { error: "Unauthorized" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "raises TokenEndpointError with status and message" do
        expect { DhanHQ.configure_from_token_endpoint(base_url: "https://myapp.com", bearer_token: bearer_token) }
          .to raise_error(DhanHQ::TokenEndpointError, /401.*Unauthorized/)
      end
    end

    context "when response lacks access_token or client_id" do
      before do
        stub_request(:get, token_url)
          .with(headers: { "Authorization" => "Bearer #{bearer_token}", "Accept" => "application/json" })
          .to_return(status: 200, body: { access_token: "t" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "raises TokenEndpointError" do
        expect { DhanHQ.configure_from_token_endpoint(base_url: "https://myapp.com", bearer_token: bearer_token) }
          .to raise_error(DhanHQ::TokenEndpointError, /missing access_token or client_id/)
      end
    end

    context "when using ENV (DHAN_TOKEN_ENDPOINT_BASE_URL and DHAN_TOKEN_ENDPOINT_BEARER)" do
      around do |example|
        ENV["DHAN_TOKEN_ENDPOINT_BASE_URL"] = "https://myapp.com"
        ENV["DHAN_TOKEN_ENDPOINT_BEARER"] = bearer_token
        example.run
      ensure
        ENV.delete("DHAN_TOKEN_ENDPOINT_BASE_URL")
        ENV.delete("DHAN_TOKEN_ENDPOINT_BEARER")
      end

      before do
        stub_request(:get, token_url)
          .with(headers: { "Authorization" => "Bearer #{bearer_token}", "Accept" => "application/json" })
          .to_return(status: 200, body: { access_token: "env_token", client_id: "env_client" }.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "uses ENV when called with no arguments" do
        DhanHQ.configure_from_token_endpoint

        expect(DhanHQ.configuration.access_token).to eq("env_token")
        expect(DhanHQ.configuration.client_id).to eq("env_client")
      end
    end
  end
end
