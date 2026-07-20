# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Registry do
  before do
    described_class.clear!
  end

  let(:test_skill) do
    Class.new(DhanHQ::Skills::Base) do
      param :symbol, type: :string, required: true
      step :run_step

      def run_step(ctx)
        ctx[:result] = "done"
        ctx
      end
    end
  end

  describe ".register" do
    it "registers a skill class" do
      described_class.register("test_skill", test_skill)

      expect(described_class.names).to include("test_skill")
    end

    it "raises for non-Base classes" do
      expect { described_class.register("bad", String) }.to raise_error(ArgumentError, /must inherit/)
    end
  end

  describe ".find" do
    it "finds a registered skill" do
      described_class.register("test_skill", test_skill)

      found = described_class.find("test_skill")
      expect(found).to eq(test_skill)
    end

    it "raises for unknown skills" do
      expect { described_class.find("nonexistent") }.to raise_error(KeyError, /Unknown skill/)
    end
  end

  describe ".call" do
    it "executes a skill by name" do
      described_class.register("test_skill", test_skill)

      result = described_class.call("test_skill", symbol: "NIFTY")
      expect(result[:result]).to eq("done")
      expect(result[:symbol]).to eq("NIFTY")
    end
  end

  describe ".list" do
    it "returns metadata for all skills" do
      described_class.register("test_skill", test_skill)

      list = described_class.list
      expect(list.length).to eq(1)
      expect(list.first[:name]).to eq("test_skill")
      expect(list.first[:params]).to include(:symbol)
      expect(list.first[:steps]).to include(:run_step)
    end
  end

  describe ".clear!" do
    it "removes all registered skills" do
      described_class.register("test_skill", test_skill)
      described_class.clear!

      expect(described_class.names).to be_empty
    end
  end

  describe ".load_builtins" do
    before do
      described_class.clear!
    end

    # rubocop:disable RSpec/MultipleExpectations
    it "registers all builtin skills" do
      described_class.load_builtins

      names = described_class.names
      expect(names).to include("buy_atm_call")
      expect(names).to include("square_off_all")
      expect(names).to include("square_off_position")
      expect(names).to include("iron_condor")
      expect(names).to include("strangle")
      expect(names).to include("covered_call")
      expect(names).to include("bull_put_spread")
      expect(names).to include("bear_call_spread")
      expect(names).to include("protective_put")
      expect(names).to include("straddle")
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "does not duplicate already registered skills" do
      described_class.register("buy_atm_call", test_skill)
      described_class.load_builtins

      found = described_class.find("buy_atm_call")
      expect(found).to eq(test_skill)
    end
  end
end
