# frozen_string_literal: true

# Guards what the published gem contains.
#
# Two failures have already happened here, in opposite directions:
#
# 1. A reject-list `spec.files` shipped a 36 MB core dump and a 17 MB diagram.html,
#    making the released gem 5.9 MB of which 5.6 MB was junk.
# 2. Replacing it with an allowlist built from "what does the Ruby runtime need"
#    silently dropped `skills/`, the Claude Agent Skill pack — product content that no
#    Ruby code loads, so no other spec noticed.
#
# These examples pin both ends: the product content that must ship, and the artifacts
# that must not.
RSpec.describe "gem packaging" do
  subject(:gemspec) { Gem::Specification.load(File.expand_path("../../DhanHQ.gemspec", __dir__)) }

  let(:files) { gemspec.files }

  describe "library and executables" do
    it "ships the entry point and both executables" do
      expect(files).to include("lib/dhan_hq.rb", "exe/dhanhq-mcp", "exe/DhanHQ")
      expect(gemspec.executables).to contain_exactly("DhanHQ", "dhanhq-mcp")
    end

    it "ships the RBS signatures and the Rails initializer" do
      expect(files).to include("sig/DhanHQ.rbs", "config/initializers/order_update_hub.rb")
    end
  end

  describe "AI-facing surfaces" do
    it "ships the MCP server" do
      expect(files).to include("lib/DhanHQ/mcp.rb", "lib/DhanHQ/mcp/server.rb")
    end

    it "ships the agent tool layer" do
      expect(files).to include(
        "lib/DhanHQ/agent/tool_registry.rb",
        "lib/DhanHQ/agent/tool_catalogue.rb",
        "lib/DhanHQ/agent/tool_schemas.rb",
        "lib/DhanHQ/agent/tool_handlers.rb"
      )
    end

    it "ships the Ruby skills classes" do
      expect(files).to include("lib/DhanHQ/skills/registry.rb", "lib/DhanHQ/skills/builtin/iron_condor.rb")
    end

    # The pack is consumed by Claude as an Agent Skill, not by this gem's runtime, so
    # nothing else in the suite would notice its absence.
    it "ships the Claude Agent Skill pack" do
      expect(files).to include("skills/dhanhq-ruby/SKILL.md")
      expect(files.grep(%r{\Askills/dhanhq-ruby/references/})).not_to be_empty
      expect(files.grep(%r{\Askills/dhanhq-ruby/examples/})).not_to be_empty
      expect(files.grep(%r{\Askills/dhanhq-ruby/scripts/})).not_to be_empty
    end
  end

  describe "excluded artifacts" do
    it "ships none of the files that bloated 3.1.0" do
      expect(files).not_to include("core", "diagram.html", "TAGS", "watchlist.csv")
    end

    it "ships no crash dump under any name" do
      expect(files.grep(/\Acore(\.|\z)|\.core\z/)).to be_empty
    end

    it "ships no test suite or fixtures" do
      expect(files.grep(%r{\Aspec/})).to be_empty
    end

    it "ships no development-only configuration" do
      expect(files).not_to include("Rakefile", ".rspec", ".rubocop.yml", ".rubocop_todo.yml", "Gemfile")
    end

    it "ships no draft PR write-ups from docs/" do
      expect(files.grep(%r{\Adocs/PR_})).to be_empty
    end
  end

  describe "payload size" do
    # A ceiling, not a target. The payload is ~1.2 MB of source and documentation; this
    # fails loudly if a large binary is ever tracked into a shipped directory again.
    let(:max_payload_bytes) { 3 * 1024 * 1024 }

    it "stays well under the size a stray binary would push it past" do
      total = files.sum { |path| File.exist?(path) ? File.size(path) : 0 }

      expect(total).to be < max_payload_bytes
    end

    it "references only files that exist" do
      expect(files.reject { |path| File.exist?(path) }).to be_empty
    end
  end
end
