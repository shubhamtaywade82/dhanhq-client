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
end
