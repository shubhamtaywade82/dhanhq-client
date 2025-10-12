# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Edis do
  describe ".resource" do
    it "memoizes the resource instance" do
      described_class.instance_variable_set(:@resource, nil)

      first = described_class.resource
      expect(first).to be_a(DhanHQ::Resources::Edis)
      expect(described_class.resource).to be(first)
    end
  end

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::Edis) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    describe ".form" do
      it "delegates to the resource" do
        params = { isin: "INE0ABCDE", qty: 1, exchange: "NSE", segment: "EQ", bulk: false }
        allow(resource_double).to receive(:form).with(params).and_return({})

        expect(described_class.form(params)).to eq({})
        expect(resource_double).to have_received(:form).with(params)
      end
    end

    describe ".bulk_form" do
      it "delegates to the resource" do
        params = { isin: %w[INE0ABCDE INE0XYZ12], exchange: "NSE", segment: "EQ" }
        allow(resource_double).to receive(:bulk_form).with(params).and_return({})

        expect(described_class.bulk_form(params)).to eq({})
        expect(resource_double).to have_received(:bulk_form).with(params)
      end
    end

    describe ".tpin" do
      it "fetches the tpin" do
        allow(resource_double).to receive(:tpin).and_return({ status: "queued" })

        expect(described_class.tpin).to eq({ status: "queued" })
        expect(resource_double).to have_received(:tpin)
      end
    end

    describe ".inquire" do
      it "requests status for the given isin" do
        allow(resource_double).to receive(:inquire).with("ALL").and_return([])

        expect(described_class.inquire("ALL")).to eq([])
        expect(resource_double).to have_received(:inquire).with("ALL")
      end
    end
  end
end
