# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Base do
  let(:test_skill_class) do
    Class.new(DhanHQ::Skills::Base) do
      param :symbol, type: :string, required: true
      param :quantity, type: :integer, default: 10

      step :step_one, priority: 1
      step :step_two, priority: 2

      def step_one(ctx)
        ctx[:step_one_done] = true
        ctx
      end

      def step_two(ctx)
        ctx[:step_two_done] = true
        ctx
      end
    end
  end

  describe ".param" do
    it "defines parameters" do
      expect(test_skill_class.params).to include(:symbol, :quantity)
    end

    it "stores parameter config" do
      config = test_skill_class.params[:symbol]
      expect(config[:type]).to eq(:string)
      expect(config[:required]).to be true
    end

    it "stores default values" do
      config = test_skill_class.params[:quantity]
      expect(config[:default]).to eq(10)
    end
  end

  describe ".step" do
    it "defines steps in priority order" do
      steps = test_skill_class.steps
      expect(steps.map { |s| s[:name] }).to eq([:step_one, :step_two])
    end
  end

  describe ".validate_params!" do
    it "passes when required params are present" do
      expect { test_skill_class.validate_params!(symbol: "NIFTY") }.not_to raise_error
    end

    it "raises when required params are missing" do
      expect { test_skill_class.validate_params!({}) }.to raise_error(ArgumentError, /Missing required parameter/)
    end

    it "passes with string keys" do
      expect { test_skill_class.validate_params!("symbol" => "NIFTY") }.not_to raise_error
    end
  end

  describe "#call" do
    it "executes all steps in order" do
      skill = test_skill_class.new
      result = skill.call(symbol: "NIFTY")

      expect(result[:step_one_done]).to be true
      expect(result[:step_two_done]).to be true
    end

    it "applies default values" do
      skill = test_skill_class.new
      result = skill.call(symbol: "NIFTY")

      expect(result[:quantity]).to eq(10)
    end

    it "overrides defaults with provided values" do
      skill = test_skill_class.new
      result = skill.call(symbol: "NIFTY", quantity: 50)

      expect(result[:quantity]).to eq(50)
    end

    it "raises on missing required params" do
      skill = test_skill_class.new

      expect { skill.call({}) }.to raise_error(ArgumentError, /Missing required parameter/)
    end
  end

  describe "#name" do
    it "returns a non-nil string" do
      skill = test_skill_class.new
      expect(skill.name).to be_a(String)
      expect(skill.name).not_to be_empty
    end
  end

  describe "#param_definitions" do
    it "returns parameter definitions" do
      skill = test_skill_class.new
      expect(skill.param_definitions).to include(:symbol, :quantity)
    end
  end
end
