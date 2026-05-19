# frozen_string_literal: true

RSpec.describe DhanHQ::Models::PnlExit do
  describe ".resource" do
    it "memoizes the resource instance" do
      described_class.instance_variable_set(:@resource, nil)

      first = described_class.resource
      expect(first).to be_a(DhanHQ::Resources::PnlExit)
      expect(described_class.resource).to be(first)
    end
  end

  context "with stubbed resource" do
    let(:resource_double) { instance_double(DhanHQ::Resources::PnlExit) }

    before do
      allow(described_class).to receive(:resource).and_return(resource_double)
    end

    describe ".configure" do
      it "sends camelized params to resource.configure" do # rubocop:disable RSpec/ExampleLength
        allow(resource_double).to receive(:configure) do |arg|
          expect(arg).to include(
            profitValue: "1500.0",
            lossValue: "500.0",
            productType: ["INTRADAY"],
            enableKillSwitch: true
          )
          { "pnlExitStatus" => "ACTIVE" }
        end

        response = described_class.configure(
          profit_value: 1500.0,
          loss_value: 500.0,
          product_type: ["INTRADAY"],
          enable_kill_switch: true
        )
        expect(response).to include("pnlExitStatus" => "ACTIVE")
      end

      it "defaults enable_kill_switch to false" do
        allow(resource_double).to receive(:configure) do |arg|
          expect(arg[:enableKillSwitch]).to be(false)
          {}
        end

        described_class.configure(
          profit_value: 1500.0,
          loss_value: 500.0,
          product_type: ["INTRADAY"]
        )
      end
    end

    describe ".stop" do
      it "delegates to resource.stop" do
        allow(resource_double).to receive(:stop)
          .and_return({ "pnlExitStatus" => "DISABLED" })

        response = described_class.stop
        expect(response).to include("pnlExitStatus" => "DISABLED")
        expect(resource_double).to have_received(:stop)
      end
    end

    describe ".status" do
      it "returns a PnlExit model instance" do
        allow(resource_double).to receive(:status)
          .and_return({
                        "pnlExitStatus" => "ACTIVE",
                        "profit" => "1500.00",
                        "loss" => "500.00",
                        "segments" => %w[INTRADAY DELIVERY],
                        "enable_kill_switch" => true
                      })

        config = described_class.status
        expect(config).to be_a(described_class)
        expect(config.pnl_exit_status).to eq("ACTIVE")
        expect(config.profit).to eq("1500.00")
        expect(config.loss).to eq("500.00")
      end

      it "returns nil when response is not a hash" do
        allow(resource_double).to receive(:status).and_return("unexpected")

        expect(described_class.status).to be_nil
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
