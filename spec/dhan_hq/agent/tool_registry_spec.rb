# frozen_string_literal: true

RSpec.describe DhanHQ::Agent::ToolRegistry do
  describe ".tools" do
    it "returns a hash of tool definitions" do
      tools = described_class.tools

      expect(tools).to be_a(Hash)
      expect(tools).not_to be_empty
    end

    it "includes dhan_profile tool" do
      tool = described_class.find("dhan_profile")

      expect(tool.name).to eq("dhan_profile")
      expect(tool.scope).to eq("portfolio:read")
      expect(tool.risk).to eq("read_only")
    end

    it "includes dhan_place_order tool with live_write risk" do
      tool = described_class.find("dhan_place_order")

      expect(tool.name).to eq("dhan_place_order")
      expect(tool.scope).to eq("orders:write")
      expect(tool.risk).to eq("live_write")
    end

    it "includes dhan_cancel_order tool with destructive_write risk" do
      tool = described_class.find("dhan_cancel_order")

      expect(tool.name).to eq("dhan_cancel_order")
      expect(tool.risk).to eq("destructive_write")
    end

    it "includes dhan_skill_iron_condor with trade_adjacent_read risk" do
      tool = described_class.find("dhan_skill_iron_condor")

      expect(tool.scope).to eq("orders:read")
      expect(tool.risk).to eq("trade_adjacent_read")
    end

    it "includes dhan_skill_square_off_all with destructive_write risk" do
      tool = described_class.find("dhan_skill_square_off_all")

      expect(tool.scope).to eq("orders:write")
      expect(tool.risk).to eq("destructive_write")
    end
  end

  describe ".find" do
    it "raises for unknown tools" do
      expect { described_class.find("nonexistent") }.to raise_error(ArgumentError, /Unknown DhanHQ agent tool/)
    end
  end

  describe ".list" do
    it "returns array of tool hashes" do
      list = described_class.list

      expect(list).to be_a(Array)
      expect(list.first).to include(:name, :description, :scope, :risk)
    end
  end

  describe ".capabilities" do
    it "returns capability manifest" do
      caps = described_class.capabilities

      expect(caps).to include(:version, :tool_count, :tools, :scopes, :risk_levels, :write_enabled)
      expect(caps[:tool_count]).to be > 0
    end
  end

  describe ".execute" do
    it "executes read-only tools" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["portfolio:read"])

      allow(DhanHQ::Models::Profile).to receive(:fetch).and_return({ client_id: "test" })

      result = described_class.execute("dhan_profile", {}, policy: policy)

      expect(result).to eq({ client_id: "test" })
    end

    it "raises on policy violation for write tools without write scope" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["portfolio:read"])

      expect do
        described_class.execute("dhan_place_order", { transaction_type: "BUY" }, policy: policy)
      end.to raise_error(DhanHQ::Error, /Agent scope required/)
    end

    it "executes a skill tool end-to-end" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["orders:read"])
      chain = build_option_chain([
                                   { strike: 24_100, ce_id: "CE_24100", ce_price: 450.0, pe_id: "PE_24100", pe_price: 20.0 },
                                   { strike: 24_300, ce_id: "CE_24300", ce_price: 300.0, pe_id: "PE_24300", pe_price: 50.0 },
                                   { strike: 24_500, ce_id: "CE_24500", ce_price: 180.0, pe_id: "PE_24500", pe_price: 100.0 },
                                   { strike: 24_700, ce_id: "CE_24700", ce_price: 90.0, pe_id: "PE_24700", pe_price: 190.0 },
                                   { strike: 24_900, ce_id: "CE_24900", ce_price: 40.0, pe_id: "PE_24900", pe_price: 320.0 }
                                 ])
      # rubocop:disable RSpec/VerifiedDoubles
      instrument = double("instrument", ltp: 24_500.0, option_chain: chain)
      # rubocop:enable RSpec/VerifiedDoubles
      allow(DhanHQ::Models::Instrument).to receive(:find).and_return(instrument)

      result = described_class.execute("dhan_skill_iron_condor", { symbol: "NIFTY", expiry: "2026-01-30" }, policy: policy)

      expect(result[:intent][:trade_type]).to eq("IRON_CONDOR")
    end

    it "raises on policy violation for skill tools without write scope" do
      policy = DhanHQ::Agent::Policy.new(scopes: ["portfolio:read"])

      expect do
        described_class.execute("dhan_skill_square_off_all", {}, policy: policy)
      end.to raise_error(DhanHQ::Error, /Agent scope required/)
    end

    describe "dhan_place_order risk pipeline" do
      let(:write_policy) { DhanHQ::Agent::Policy.new(scopes: ["orders:write"]) }
      let(:order_args) do
        {
          transaction_type: "BUY",
          exchange_segment: "NSE_EQ",
          product_type: "INTRADAY",
          order_type: "MARKET",
          validity: "DAY",
          security_id: "2885",
          quantity: 5,
          price: 100
        }
      end

      # rubocop:disable RSpec/VerifiedDoubles
      let(:compliant_instrument) do
        double("instrument",
               instrument_type: "EQUITY",
               buy_sell_indicator: "A",
               asm_gsm_flag: "N",
               bracket_flag: "N",
               cover_flag: "N")
      end
      # rubocop:enable RSpec/VerifiedDoubles

      around do |example|
        original_writes = ENV.fetch("DHANHQ_MCP_ENABLE_WRITES", nil)
        original_live = ENV.fetch("LIVE_TRADING", nil)
        ENV["DHANHQ_MCP_ENABLE_WRITES"] = "true"
        ENV["LIVE_TRADING"] = "true"
        example.run
        ENV["DHANHQ_MCP_ENABLE_WRITES"] = original_writes
        ENV["LIVE_TRADING"] = original_live
      end

      before do
        # rubocop:disable RSpec/VerifiedDoubles
        allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(double("funds", available_balance: 100_000))
        # rubocop:enable RSpec/VerifiedDoubles
        allow(DhanHQ::Models::Position).to receive(:all).and_return([])
      end

      it "places the order when the resolved instrument passes every risk check" do
        allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).with("NSE_EQ", "2885").and_return(compliant_instrument)
        allow(DhanHQ::Models::Order).to receive(:place).and_return(instance_double(DhanHQ::Models::Order))
        market_hours_now = Time.new(2026, 1, 30, 10, 0, 0, "+05:30")
        allow(DhanHQ::Risk::Checks::MarketHours).to(receive(:run!).and_wrap_original { |method, **kwargs| method.call(now: market_hours_now, **kwargs.except(:now)) })

        described_class.execute("dhan_place_order", order_args, policy: write_policy)

        expect(DhanHQ::Models::Order).to have_received(:place)
      end

      it "blocks the order and never calls Order.place when the instrument cannot be resolved" do
        allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(nil)
        allow(DhanHQ::Models::Order).to receive(:place)

        expect do
          described_class.execute("dhan_place_order", order_args, policy: write_policy)
        end.to raise_error(DhanHQ::RiskViolation, /unknown instrument/i)

        expect(DhanHQ::Models::Order).not_to have_received(:place)
      end

      it "blocks the order and never calls Order.place when the instrument fails a risk check" do
        # rubocop:disable RSpec/VerifiedDoubles
        restricted_instrument = double("instrument",
                                       instrument_type: "EQUITY",
                                       buy_sell_indicator: "A",
                                       asm_gsm_flag: "Y",
                                       asm_gsm_category: "ASM Stage 1")
        # rubocop:enable RSpec/VerifiedDoubles
        allow(DhanHQ::Models::Instrument).to receive(:find_by_security_id).and_return(restricted_instrument)
        allow(DhanHQ::Models::Order).to receive(:place)

        expect do
          described_class.execute("dhan_place_order", order_args, policy: write_policy)
        end.to raise_error(DhanHQ::RiskViolation, %r{ASM/GSM})

        expect(DhanHQ::Models::Order).not_to have_received(:place)
      end
    end
  end
end
