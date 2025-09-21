# frozen_string_literal: true

RSpec.describe DhanHQ::Models::KillSwitch do
  let(:resource_double) { instance_double(DhanHQ::Resources::KillSwitch) }

  before do
    allow(described_class).to receive(:resource).and_return(resource_double)
  end

  describe ".update" do
    it "delegates to the resource with snake_case params" do
      expect(resource_double).to receive(:update).with(kill_switch_status: "ACTIVATE")
                                                 .and_return({ "killSwitchStatus" => "ACTIVATE" })

      response = described_class.update("ACTIVATE")
      expect(response).to eq({ "killSwitchStatus" => "ACTIVATE" })
    end
  end

  describe ".activate" do
    it "sets the kill switch to ACTIVATE" do
      expect(described_class).to receive(:update).with("ACTIVATE").and_return({})
      expect(described_class.activate).to eq({})
    end
  end

  describe ".deactivate" do
    it "sets the kill switch to DEACTIVATE" do
      expect(described_class).to receive(:update).with("DEACTIVATE").and_return({})
      expect(described_class.deactivate).to eq({})
    end
  end
end

