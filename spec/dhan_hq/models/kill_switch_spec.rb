# frozen_string_literal: true

RSpec.describe DhanHQ::Models::KillSwitch do
  describe ".resource" do
    it "memoizes the resource instance" do
      described_class.instance_variable_set(:@resource, nil)

      first = described_class.resource
      expect(first).to be_a(DhanHQ::Resources::KillSwitch)
      expect(described_class.resource).to be(first)
    end
  end

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::KillSwitch) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    describe ".update" do
      it "delegates to the resource with snake_case params" do
        allow(resource_double).to receive(:update).with(kill_switch_status: "ACTIVATE")
                                                  .and_return({ "killSwitchStatus" => "ACTIVATE" })

        response = described_class.update("ACTIVATE")
        expect(response).to eq({ "killSwitchStatus" => "ACTIVATE" })
        expect(resource_double).to have_received(:update).with(kill_switch_status: "ACTIVATE")
      end
    end

    describe ".activate" do
      it "sets the kill switch to ACTIVATE" do
        allow(described_class).to receive(:update).with("ACTIVATE").and_return({})
        expect(described_class.activate).to eq({})
        expect(described_class).to have_received(:update).with("ACTIVATE")
      end
    end

    describe ".deactivate" do
      it "sets the kill switch to DEACTIVATE" do
        allow(described_class).to receive(:update).with("DEACTIVATE").and_return({})
        expect(described_class.deactivate).to eq({})
        expect(described_class).to have_received(:update).with("DEACTIVATE")
      end
    end

    describe ".status" do
      it "delegates to resource.status" do
        allow(resource_double).to receive(:status)
          .and_return({ "killSwitchStatus" => "ACTIVATE" })

        response = described_class.status
        expect(response).to eq({ "killSwitchStatus" => "ACTIVATE" })
        expect(resource_double).to have_received(:status)
      end
    end
  end
end
