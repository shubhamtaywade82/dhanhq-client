# frozen_string_literal: true

RSpec.describe DhanHQ::Configuration do
  let(:live_url) { DhanHQ::Configuration::BASE_URL }
  let(:sandbox_url) { DhanHQ::Configuration::SANDBOX_URL }
  let(:config) { described_class.new(client_id: "1000000001", access_token: "test-token", mode: mode) }

  after do
    ENV.delete("DHAN_MODE")
    ENV.delete("DHAN_SANDBOX")
  end

  describe "#mode" do
    let(:mode) { :live }

    it "defaults to :live" do
      expect(config.mode).to eq(:live)
      expect(config.sandbox?).to be false
      expect(config.hybrid?).to be false
      expect(config.base_url).to eq(live_url)
    end

    it "reads DHAN_MODE from ENV" do
      ENV["DHAN_MODE"] = "hybrid"

      expect(described_class.new.mode).to eq(:hybrid)
    end

    it "keeps DHAN_SANDBOX=true working as a legacy alias" do
      ENV["DHAN_SANDBOX"] = "true"

      configuration = described_class.new

      expect(configuration.mode).to eq(:sandbox)
      expect(configuration.sandbox).to be true
      expect(configuration.base_url).to eq(sandbox_url)
    end

    it "prefers an explicit mode attribute over DHAN_SANDBOX" do
      ENV["DHAN_SANDBOX"] = "true"

      expect(described_class.new(mode: :live).mode).to eq(:live)
    end

    it "rejects unknown modes with a helpful error" do
      expect { config.mode = :staging }
        .to raise_error(ArgumentError, /unknown mode :staging.*live, sandbox, hybrid/)
    end

    it "switches the legacy sandbox flag back to live" do
      configuration = described_class.new
      configuration.sandbox = true
      expect(configuration.mode).to eq(:sandbox)

      configuration.sandbox = false
      expect(configuration.mode).to eq(:live)
    end
  end

  describe "#environment_for and #base_url_for" do
    context "when mode is :live" do
      let(:mode) { :live }

      it "routes every tier to production" do
        %i[order_api data_api quote_api option_chain non_trading_api global_stocks_api].each do |tier|
          expect(config.environment_for(tier)).to eq(:live)
          expect(config.base_url_for(tier)).to eq(live_url)
        end
      end
    end

    context "when mode is :sandbox" do
      let(:mode) { :sandbox }

      it "routes every tier to the sandbox host" do
        %i[order_api data_api quote_api option_chain non_trading_api global_stocks_api].each do |tier|
          expect(config.environment_for(tier)).to eq(:sandbox)
          expect(config.base_url_for(tier)).to eq(sandbox_url)
        end
      end
    end

    context "when mode is :hybrid" do
      let(:mode) { :hybrid }

      it "keeps market data on production" do
        %i[data_api quote_api option_chain].each do |tier|
          expect(config.environment_for(tier)).to eq(:live)
          expect(config.base_url_for(tier)).to eq(live_url)
        end
      end

      it "routes trading and account tiers to the sandbox host" do
        %i[order_api non_trading_api].each do |tier|
          expect(config.environment_for(tier)).to eq(:sandbox)
          expect(config.base_url_for(tier)).to eq(sandbox_url)
        end
      end

      it "keeps Global Stocks on production (sandbox host does not mirror it)" do
        expect(config.environment_for(:global_stocks_api)).to eq(:live)
      end

      it "lets per-tier overrides win over the mode defaults" do
        config.environment_overrides = { non_trading_api: :live, data_api: :sandbox }

        expect(config.environment_for(:non_trading_api)).to eq(:live)
        expect(config.base_url_for(:non_trading_api)).to eq(live_url)
        expect(config.environment_for(:data_api)).to eq(:sandbox)
        expect(config.base_url_for(:data_api)).to eq(sandbox_url)
        expect(config.environment_for(:order_api)).to eq(:sandbox)
      end

      it "accepts string-form overrides (DHAN_ENV_OVERRIDES compatible)" do
        config.environment_overrides = "order_api=live"

        expect(config.environment_for(:order_api)).to eq(:live)
      end

      it "rejects invalid override values" do
        expect { config.environment_overrides = { order_api: :staging } }
          .to raise_error(ArgumentError, /must be :live or :sandbox/)
      end
    end

    it "lets an explicit base_url override every environment decision" do
      configuration = described_class.new(mode: :sandbox)
      configuration.base_url = "https://custom.proxy.example"

      expect(configuration.base_url_for(:order_api)).to eq("https://custom.proxy.example")
    end
  end
end
