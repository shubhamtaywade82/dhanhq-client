# frozen_string_literal: true

# Guards against a bug class that has bitten this gem twice: a source file whose
# constant doesn't match Zeitwerk's inferred name from its path needs an explicit
# inflector entry, or the constant is unreachable via a bare `require "dhan_hq"`.
#
# `ai.rb` defines `DhanHQ::AI` (Zeitwerk expected `DhanHQ::Ai`) and `mcp.rb` defines
# `DhanHQ::MCP` (Zeitwerk expected `DhanHQ::Mcp`). Both only worked before their fixes
# because something else happened to `require_relative` the file by hand first --
# `spec/dhan_hq/mcp/server_spec.rb` still does, which is why it never caught the MCP
# case. A same-process check here would suffer the same blind spot: by the time this
# file runs, those other specs have already loaded both constants by hand, so the
# check must run in a fresh subprocess that requires nothing but "dhan_hq".
RSpec.describe "Zeitwerk inflector coverage" do
  def reachable?(constant_path)
    root = File.expand_path("../..", __dir__)
    script = "require \"dhan_hq\"; #{constant_path}"
    system({ "BUNDLE_GEMFILE" => File.join(root, "Gemfile") },
           RbConfig.ruby, "-I", File.join(root, "lib"), "-e", script,
           out: File::NULL, err: File::NULL)
  end

  it "reaches DhanHQ::AI::PromptHelpers via the autoloader alone" do
    expect(reachable?("DhanHQ::AI::PromptHelpers")).to be(true)
  end

  it "reaches DhanHQ::MCP::Server via the autoloader alone" do
    expect(reachable?("DhanHQ::MCP::Server")).to be(true)
  end
end
