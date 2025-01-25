# frozen_string_literal: true

require "DhanHQ"

RSpec.describe DhanHQ do
  describe ".configure_with_env" do
    before do
      ENV["ACCESS_TOKEN"] = "env_access_token"
      ENV["CLIENT_ID"] = "env_client_id"
    end

    it "configures access_token and client_id from environment variables" do
      described_class.configure_with_env

      expect(described_class.configuration.access_token).to eq("env_access_token")
      expect(described_class.configuration.client_id).to eq("env_client_id")
    end
  end

  describe ".configure" do
    it "allows manual configuration with a block" do
      described_class.configure do |config|
        config.access_token = "block_access_token"
        config.client_id = "block_client_id"
      end

      expect(described_class.configuration.access_token).to eq("block_access_token")
      expect(described_class.configuration.client_id).to eq("block_client_id")
    end
  end
end
