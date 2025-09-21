# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Edis do
  let(:resource_double) { instance_double(DhanHQ::Resources::Edis) }

  before do
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".form" do
    it "delegates to the resource" do
      params = { isin: "INE0ABCDE", qty: 1, exchange: "NSE", segment: "EQ", bulk: false }
      expect(resource_double).to receive(:form).with(params).and_return({})

      expect(described_class.form(params)).to eq({})
    end
  end

  describe ".bulk_form" do
    it "delegates to the resource" do
      params = { isin: %w[INE0ABCDE INE0XYZ12], exchange: "NSE", segment: "EQ" }
      expect(resource_double).to receive(:bulk_form).with(params).and_return({})

      expect(described_class.bulk_form(params)).to eq({})
    end
  end

  describe ".tpin" do
    it "fetches the tpin" do
      expect(resource_double).to receive(:tpin).and_return({ status: "queued" })

      expect(described_class.tpin).to eq({ status: "queued" })
    end
  end

  describe ".inquire" do
    it "requests status for the given isin" do
      expect(resource_double).to receive(:inquire).with("ALL").and_return([])

      expect(described_class.inquire("ALL")).to eq([])
    end
  end
end

