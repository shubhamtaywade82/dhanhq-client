# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::PnlExit do
  subject(:resource) { described_class.new }

  let(:configure_params) do
    { "profitValue" => 500.0, "lossValue" => 300.0, "productType" => "INTRADAY", "enableKillSwitch" => false }
  end

  before do
    DhanHQ.configure_with_env
    DhanHQ::Utils::NetworkInspector.reset_cache!
    stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
    stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")
  end

  after { DhanHQ::Utils::NetworkInspector.reset_cache! }

  describe "#configure — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.configure(configure_params) }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#stop — live trading guard" do
    context "when LIVE_TRADING is not 'true'" do
      before { stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false")) }

      it "raises LiveTradingDisabledError" do
        expect { resource.stop }
          .to raise_error(DhanHQ::LiveTradingDisabledError)
      end
    end
  end

  describe "#configure audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:post, %r{/v2/pnlExit}).to_return(
        status: 200,
        body: { pnlExitStatus: "ACTIVE" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_PNL_EXIT_CONFIGURE_ATTEMPT" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.configure(configure_params)

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_PNL_EXIT_CONFIGURE_ATTEMPT")
    end
  end

  describe "#stop audit log" do
    before do
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "true"))
      stub_request(:delete, %r{/v2/pnlExit}).to_return(
        status: 200,
        body: { pnlExitStatus: "INACTIVE" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end

    it "logs DHAN_PNL_EXIT_STOP_ATTEMPT" do
      log_lines = []
      allow(DhanHQ.logger).to receive(:warn) { |msg| log_lines << msg }

      resource.stop

      parsed = JSON.parse(log_lines.first)
      expect(parsed["event"]).to eq("DHAN_PNL_EXIT_STOP_ATTEMPT")
    end
  end

  describe "#status" do
    it "does not require LIVE_TRADING to be set" do
      stub_request(:get, %r{/v2/pnlExit}).to_return(
        status: 200,
        body: { pnlExitStatus: "INACTIVE" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
      stub_const("ENV", ENV.to_h.merge("LIVE_TRADING" => "false"))

      expect { resource.status }.not_to raise_error
    end
  end
end
