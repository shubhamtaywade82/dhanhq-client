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
end
