# frozen_string_literal: true

RSpec.describe DhanHQ::Skills::Workflow do
  describe "#call" do
    # rubocop:disable RSpec/ExampleLength
    it "executes steps in priority order" do
      order = []
      workflow = described_class.new do
        step :first, priority: 1 do |ctx|
          order << :first
          ctx
        end

        step :second, priority: 2 do |ctx|
          order << :second
          ctx
        end

        step :third, priority: 3 do |ctx|
          order << :third
          ctx
        end
      end

      workflow.call({})
      expect(order).to eq(%i[first second third])
    end
    # rubocop:enable RSpec/ExampleLength

    it "passes context between steps" do
      workflow = described_class.new do
        step :set_value do |ctx|
          ctx[:value] = 42
          ctx
        end

        step :use_value do |ctx|
          ctx[:doubled] = ctx[:value] * 2
          ctx
        end
      end

      result = workflow.call({})
      expect(result[:value]).to eq(42)
      expect(result[:doubled]).to eq(84)
    end

    it "raises on step failure" do
      workflow = described_class.new do
        step :fail do |_ctx|
          raise "Something went wrong"
        end
      end

      expect { workflow.call({}) }.to raise_error(RuntimeError, "Something went wrong")
    end

    it "accepts initial context" do
      workflow = described_class.new do
        step :use_input do |ctx|
          ctx[:output] = ctx[:input] + 1
          ctx
        end
      end

      result = workflow.call(input: 10)
      expect(result[:output]).to eq(11)
    end
  end

  describe "#steps" do
    it "returns steps sorted by priority" do
      workflow = described_class.new do
        step :low, priority: 3 do |ctx|
          ctx
        end

        step :high, priority: 1 do |ctx|
          ctx
        end

        step :mid, priority: 2 do |ctx|
          ctx
        end
      end

      expect(workflow.steps.map(&:name)).to eq(%i[high mid low])
    end
  end

  describe "#name" do
    it "defaults to 'workflow'" do
      workflow = described_class.new
      expect(workflow.name).to eq("workflow")
    end

    it "accepts custom name" do
      workflow = described_class.new(name: "my_workflow")
      expect(workflow.name).to eq("my_workflow")
    end
  end
end
