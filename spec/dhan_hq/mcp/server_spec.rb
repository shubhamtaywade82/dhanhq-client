# frozen_string_literal: true

require "stringio"
require "DhanHQ/mcp"

RSpec.describe DhanHQ::MCP::Server do
  it "responds to tools/list" do
    output = StringIO.new
    server = described_class.new(input: StringIO.new, output: output, policy: DhanHQ::Agent::Policy.read_only)

    server.handle_line({ jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }.to_json)

    response = JSON.parse(output.string)
    expect(response.dig("result", "tools").map { |tool| tool["name"] }).to include("dhan_order_preview")
  end
end
