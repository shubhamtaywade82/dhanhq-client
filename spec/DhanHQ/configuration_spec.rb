# frozen_string_literal: true

require "DhanHQ"

RSpec.describe DhanHQ::Configuration do
  subject(:config) { described_class.new }

  describe "#initialize" do
    it "initializes with default values" do
      expect(config.client_id).to be_nil
      expect(config.access_token).to be_nil
      expect(config.base_url).to eq("https://api.dhan.co/v2")
      expect(config.compact_csv_url).to eq("https://images.dhan.co/api-data/api-scrip-master.csv")
      expect(config.detailed_csv_url).to eq("https://images.dhan.co/api-data/api-scrip-master-detailed.csv")
    end
  end

  describe "attribute accessors" do
    it "allows setting and getting client_id" do
      config.client_id = "test_client_id"
      expect(config.client_id).to eq("test_client_id")
    end

    it "allows setting and getting access_token" do
      config.access_token = "test_access_token"
      expect(config.access_token).to eq("test_access_token")
    end
  end
end
