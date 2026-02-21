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

    describe ".generate_tpin" do
      it "delegates to resource.tpin" do
        allow(resource_double).to receive(:tpin).and_return({ "status" => "ok" })

        response = described_class.generate_tpin
        expect(response).to include("status" => "ok")
        expect(resource_double).to have_received(:tpin)
      end
    end

    describe ".generate_form" do
      it "delegates to resource.form with the correct params" do
        allow(resource_double).to receive(:form) do |params|
          expect(params).to include(isin: "INE155A01022", qty: 10, exchange: "NSE", segment: "E", bulk: false)
          { "formHtml" => "<html>...</html>" }
        end

        response = described_class.generate_form(
          isin: "INE155A01022",
          qty: 10,
          exchange: "NSE",
          segment: "E"
        )
        expect(response).to include("formHtml")
      end

      it "defaults bulk to false" do
        allow(resource_double).to receive(:form) do |params|
          expect(params[:bulk]).to be(false)
          {}
        end

        described_class.generate_form(isin: "X", qty: 1, exchange: "NSE", segment: "E")
      end
    end

    describe ".generate_bulk_form" do
      it "delegates to resource.bulk_form" do
        allow(resource_double).to receive(:bulk_form).and_return({ "formHtml" => "bulk" })

        response = described_class.generate_bulk_form({ exchange: "NSE", segment: "E", bulk: true })
        expect(response).to include("formHtml" => "bulk")
        expect(resource_double).to have_received(:bulk_form)
      end
    end

    describe ".inquire" do
      it "delegates to resource.inquire" do
        allow(resource_double).to receive(:inquire)
          .with("INE155A01022")
          .and_return({ "approvalStatus" => "approved" })

        response = described_class.inquire(isin: "INE155A01022")
        expect(response).to include("approvalStatus" => "approved")
        expect(resource_double).to have_received(:inquire).with("INE155A01022")
      end
    end
  end

  describe "#validation_contract" do
    it "returns nil" do
      instance = described_class.new({}, skip_validation: true)
      expect(instance.validation_contract).to be_nil
    end
  end
end
