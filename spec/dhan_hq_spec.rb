# frozen_string_literal: true

RSpec.describe DhanHQ do
  it "has a version number" do
    expect(DhanHQ::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "allows setting the configuration with a block" do
      described_class.configure do |config|
        config.access_token = "test_access_token"
        config.client_id = "test_client_id"
      end

      expect(described_class.configuration.access_token).to eq("test_access_token")
      expect(described_class.configuration.client_id).to eq("test_client_id")
    end

    it "creates a new configuration instance if none exists" do
      described_class.configuration = nil

      described_class.configure do |config|
        config.access_token = "new_access_token"
      end

      expect(described_class.configuration).to be_a(DhanHQ::Configuration)
      expect(described_class.configuration.access_token).to eq("new_access_token")
    end
  end

  describe ".ensure_configuration!" do
    it "creates configuration from ENV when nil" do
      described_class.configuration = nil
      ENV["DHAN_CLIENT_ID"] = "ensure_client_id"
      ENV["DHAN_ACCESS_TOKEN"] = "ensure_token"

      result = described_class.ensure_configuration!

      expect(result).to be_a(DhanHQ::Configuration)
      expect(result.client_id).to eq("ensure_client_id")
      expect(result.access_token).to eq("ensure_token")
    end

    it "returns existing configuration when already set" do
      described_class.configure { |c| c.client_id = "existing" }
      existing = described_class.configuration

      result = described_class.ensure_configuration!

      expect(result).to equal(existing)
      expect(result.client_id).to eq("existing")
    end
  end

  describe "resource client refresh on configuration replacement" do
    it "updates memoized model resources when configuration is replaced" do
      described_class.configure do |config|
        config.access_token = "initial_token"
        config.client_id = "initial_client"
      end

      expect(DhanHQ::Models::Order.resource.client.config.access_token).to eq("initial_token")

      described_class.configure do |config|
        config.access_token = "updated_token"
        config.client_id = "updated_client"
      end

      expect(DhanHQ::Models::Order.resource.client.config.access_token).to eq("updated_token")
      expect(DhanHQ::Models::Order.resource.client.config.client_id).to eq("updated_client")
    end

    it "refreshes client when configuration is directly assigned" do
      expect(DhanHQ::Models::Order.resource).not_to be_nil
      new_config = DhanHQ::Configuration.new(access_token: "direct_token", client_id: "direct_client")

      described_class.configuration = new_config

      expect(DhanHQ::Models::Order.resource.client.config.access_token).to eq("direct_token")
      expect(DhanHQ::Models::Order.resource.client.config.client_id).to eq("direct_client")
    end
  end
end
