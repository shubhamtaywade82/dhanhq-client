# frozen_string_literal: true

RSpec.describe DhanHQ::Models::AlertOrder do
  describe ".resource" do
    it "memoizes the resource instance" do
      described_class.instance_variable_set(:@resource, nil)

      first = described_class.resource
      expect(first).to be_a(DhanHQ::Resources::AlertOrders)
      expect(described_class.resource).to be(first)
    end
  end

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::AlertOrders) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    describe ".all" do
      it "returns model instances when the response is an array" do
        allow(resource_double).to receive(:all).and_return([{ "alertId" => "AID-1" }])

        result = described_class.all

        expect(result).to all(be_a(described_class))
        expect(result.first.alert_id).to eq("AID-1")
      end

      it "returns an empty array when the response is not an array" do
        allow(resource_double).to receive(:all).and_return("unexpected")

        expect(described_class.all).to eq([])
      end
    end

    describe ".find" do
      it "returns nil when the response is nil or not a hash/array" do
        allow(resource_double).to receive(:find).with("AID-1").and_return(nil)

        expect(described_class.find("AID-1")).to be_nil
      end

      it "wraps the response in a model" do
        allow(resource_double).to receive(:find).with("AID-1")
                                                .and_return({ "alertId" => "AID-1", "triggerPrice" => 100.0 })

        record = described_class.find("AID-1")
        expect(record).to be_a(described_class)
        expect(record.alert_id).to eq("AID-1")
      end

      it "unwraps array response to first element" do
        allow(resource_double).to receive(:find).with("AID-1")
                                                .and_return([{ "alertId" => "AID-1" }])

        record = described_class.find("AID-1")
        expect(record).to be_a(described_class)
        expect(record.alert_id).to eq("AID-1")
      end
    end

    describe ".create" do
      let(:valid_params) do
        {
          exchange_segment: "NSE_EQ",
          security_id: "11536",
          condition: "GTE",
          trigger_price: 100.0,
          transaction_type: "BUY",
          quantity: 10
        }
      end

      it "returns nil when the API does not return an alertId" do
        allow(resource_double).to receive(:create).and_return({ "status" => "fail" })

        expect(described_class.create(valid_params)).to be_nil
      end

      it "validates params and fetches the created alert when alertId is present" do
        allow(resource_double).to receive(:create).and_return({ "alertId" => "AID-1" })
        allow(resource_double).to receive(:find).with("AID-1")
                                                .and_return({ "alertId" => "AID-1", "triggerPrice" => 100.0 })

        record = described_class.create(valid_params)
        expect(record).to be_a(described_class)
        expect(record.alert_id).to eq("AID-1")
      end

      it "raises when validation fails" do
        invalid_params = valid_params.merge(quantity: -1)

        expect { described_class.create(invalid_params) }.to raise_error(DhanHQ::Error, /Validation Error/)
      end
    end

    describe "#id" do
      it "returns alert_id as string" do
        record = described_class.new({ "alertId" => "AID-99" }, skip_validation: true)
        expect(record.id).to eq("AID-99")
      end

      it "returns nil when alert_id is nil" do
        record = described_class.new({}, skip_validation: true)
        expect(record.id).to be_nil
      end
    end

    describe "#save (new record)" do
      let(:record) do
        described_class.new(
          {
            exchange_segment: "NSE_EQ",
            security_id: "11536",
            condition: "GTE",
            trigger_price: 100.0,
            transaction_type: "BUY",
            quantity: 10
          },
          skip_validation: true
        )
      end

      it "returns false when invalid" do
        allow(record).to receive(:valid?).and_return(false)

        expect(record.save).to be(false)
      end

      it "returns false when create does not return alertId" do
        allow(resource_double).to receive(:create).and_return({})

        expect(record.save).to be(false)
      end

      it "returns true and updates attributes when create returns alertId" do
        allow(resource_double).to receive(:create).and_return({ "alertId" => "AID-NEW" })

        expect(record.save).to be(true)
        expect(record.alert_id).to eq("AID-NEW")
      end
    end

    describe "#save (persisted)" do
      let(:record) { described_class.new({ "alertId" => "AID-1" }, skip_validation: true) }

      before do
        allow(record).to receive(:valid?).and_return(true)
      end

      it "returns false when update response is not successful" do
        allow(resource_double).to receive(:update).and_return({ "status" => "fail" })

        expect(record.save).to be(false)
      end

      it "returns true and updates attributes when update is successful" do
        allow(resource_double).to receive(:update)
          .and_return({ status: "success", triggerPrice: 105.0 })

        expect(record.save).to be(true)
      end
    end

    describe "#destroy" do
      it "returns false for new records" do
        record = described_class.new({}, skip_validation: true)

        expect(record.destroy).to be(false)
      end

      it "returns true when delete succeeds" do
        record = described_class.new({ "alertId" => "AID-1" }, skip_validation: true)
        allow(resource_double).to receive(:delete).with("AID-1").and_return({ status: "success" })

        expect(record.destroy).to be(true)
      end

      it "returns false when delete fails" do
        record = described_class.new({ "alertId" => "AID-1" }, skip_validation: true)
        allow(resource_double).to receive(:delete).with("AID-1").and_return({ "status" => "fail" })

        expect(record.destroy).to be(false)
      end
    end

    describe "#delete" do
      it "is an alias of destroy" do
        record = described_class.new({ "alertId" => "AID-1" }, skip_validation: true)
        allow(resource_double).to receive(:delete).with("AID-1").and_return({ status: "success" })

        expect(record.delete).to be(true)
      end
    end

    describe ".modify" do
      it "updates and re-fetches the alert order on success" do
        allow(resource_double).to receive(:update)
          .with("AID-1", hash_including("comparingValue" => 300))
          .and_return({ status: "success" })
        allow(resource_double).to receive(:find).with("AID-1")
                                                .and_return({ "alertId" => "AID-1", "triggerPrice" => 300.0 })

        result = described_class.modify("AID-1", comparing_value: 300)
        expect(result).to be_a(described_class)
        expect(result.alert_id).to eq("AID-1")
      end

      it "returns nil when the update fails" do
        allow(resource_double).to receive(:update).and_return({ "status" => "fail" })

        expect(described_class.modify("AID-1", comparing_value: 300)).to be_nil
      end
    end
  end
end
