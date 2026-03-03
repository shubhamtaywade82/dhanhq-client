# frozen_string_literal: true

# rubocop:disable RSpec/SpecFilePathFormat

require "spec_helper"
require "rubocop"
require "rubocop/cop/dhanhq/use_constants"

RSpec.describe RuboCop::Cop::DhanHQ::UseConstants do
  subject(:cop) { described_class.new(config) }

  let(:config) { RuboCop::Config.new }

  def offenses_for(source)
    processed_source = RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f)
    commissioner = RuboCop::Cop::Commissioner.new([cop])
    commissioner.investigate(processed_source).offenses
  end

  def offense_messages(source)
    offenses_for(source).map(&:message)
  end

  context "when a string matches an unambiguous constant" do
    it "flags bare string assignment" do
      msgs = offense_messages('type = "BUY"')
      expect(msgs).to include(/TransactionType::BUY/)
    end

    it "flags the value side of a hash pair" do
      msgs = offense_messages('{ transaction_type: "SELL" }')
      expect(msgs).to include(/TransactionType::SELL/)
    end

    it "flags NSE_COMM" do
      expect(offense_messages('segment = "NSE_COMM"')).to include(/ExchangeSegment::NSE_COMM/)
    end

    it "flags MODIFIED" do
      expect(offense_messages('status = "MODIFIED"')).to include(/OrderStatus::MODIFIED/)
    end
  end

  context "when the string is a hash key" do
    it "does not flag hash keys" do
      expect(offenses_for('{ "BUY" => 1 }')).to be_empty
    end
  end

  context "when the string is inside a %w[] array" do
    it "does not flag percent-word arrays" do
      expect(offenses_for("types = %w[BUY SELL]")).to be_empty
    end
  end

  context "when the string is passed to raise" do
    it "does not flag raise arguments" do
      expect(offenses_for('raise "BUY order failed"')).to be_empty
    end
  end

  context "with AMBIGUOUS_CONSTANTS (OPEN, INDEX)" do
    it "does not flag OPEN in a bare string context" do
      expect(offenses_for('msg = "OPEN"')).to be_empty
    end

    it "flags OPEN when it is the value side of a hash pair" do
      msgs = offense_messages('{ amo_time: "OPEN" }')
      expect(msgs).to include(/AmoTime::OPEN/)
    end

    it "does not flag INDEX in a bare string context" do
      expect(offenses_for('instrument = "INDEX"')).to be_empty
    end

    it "flags INDEX when it is the value side of a hash pair" do
      msgs = offense_messages('{ instrument_type: "INDEX" }')
      expect(msgs).to include(/InstrumentType::INDEX/)
    end
  end

  context "with auto-correction" do
    it "generates an offense with a corrector for BUY" do
      offenses = offenses_for('type = "BUY"')
      expect(offenses).not_to be_empty
      expect(offenses.first.message).to include("TransactionType::BUY")
      expect(offenses.first.corrector).not_to be_nil
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
