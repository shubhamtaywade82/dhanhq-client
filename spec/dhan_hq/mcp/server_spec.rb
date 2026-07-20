# frozen_string_literal: true

# rubocop:disable RSpec/VerifiedDoubles
require "dhan_hq"
require_relative "../../../lib/DhanHQ/mcp"
require_relative "../../../lib/DhanHQ/ai"

RSpec.describe DhanHQ::MCP::Server do
  subject(:server) { described_class.new(input: input, output: output, policy: policy) }

  let(:input) { StringIO.new }
  let(:output) { StringIO.new }
  let(:policy) { DhanHQ::Agent::Policy.read_only }

  def send_request(method, params = {}, id: 1)
    input.puts(JSON.generate({ jsonrpc: "2.0", id: id, method: method, params: params }))
    input.rewind
    server.run
    output.rewind
    JSON.parse(output.read)
  end

  describe "initialize" do
    it "responds with protocol version and server info" do
      response = send_request("initialize")

      expect(response["id"]).to eq(1)
      expect(response.dig("result", "protocolVersion")).to eq("2024-11-05")
      expect(response.dig("result", "serverInfo", "name")).to eq("dhanhq-ruby")
      expect(response.dig("result", "capabilities")).to include("tools", "resources", "prompts")
    end
  end

  describe "tools/list" do
    it "returns tool definitions" do
      response = send_request("tools/list")

      expect(response["id"]).to eq(1)
      tools = response.dig("result", "tools")
      expect(tools).to be_an(Array)
      expect(tools).not_to be_empty
      expect(tools.first).to include("name", "description", "inputSchema")
    end

    it "includes dhan_profile tool with risk badge" do
      response = send_request("tools/list")
      tools = response.dig("result", "tools")
      profile = tools.find { |t| t["name"] == "dhan_profile" }

      expect(profile["description"]).to include("[read_only]")
    end

    it "includes dhan_place_order tool with risk badge" do
      response = send_request("tools/list")
      tools = response.dig("result", "tools")
      place_order = tools.find { |t| t["name"] == "dhan_place_order" }

      expect(place_order["description"]).to include("[live_write]")
    end
  end

  describe "tools/call" do
    it "executes read-only tools with policy" do
      allow(DhanHQ::Models::Profile).to receive(:fetch).and_return({ client_id: "test" })

      response = send_request("tools/call", { name: "dhan_profile", arguments: {} })

      expect(response["id"]).to eq(1)
      expect(response.dig("result", "content").first["type"]).to eq("text")
    end

    it "rejects write tools with read-only policy" do
      response = send_request("tools/call", { name: "dhan_place_order", arguments: { transaction_type: "BUY" } })

      expect(response["error"]).not_to be_nil
    end
  end

  describe "resources/list" do
    # rubocop:disable RSpec/MultipleExpectations
    it "returns resource definitions" do
      response = send_request("resources/list")

      expect(response["id"]).to eq(1)
      resources = response.dig("result", "resources")
      expect(resources).to be_an(Array)
      expect(resources).not_to be_empty

      uris = resources.map { |r| r["uri"] }
      expect(uris).to include("dhanhq://account/profile")
      expect(uris).to include("dhanhq://account/funds")
      expect(uris).to include("dhanhq://account/holdings")
      expect(uris).to include("dhanhq://account/positions")
      expect(uris).to include("dhanhq://account/orders")
      expect(uris).to include("dhanhq://market/capabilities")
    end
    # rubocop:enable RSpec/MultipleExpectations

    it "includes name and mimeType for each resource" do
      response = send_request("resources/list")
      resources = response.dig("result", "resources")

      resources.each do |r|
        expect(r).to include("name", "uri", "mimeType")
        expect(r["mimeType"]).to eq("application/json")
      end
    end
  end

  describe "resources/read" do
    it "reads profile resource" do
      profile_data = { client_id: "test_client", pan: "ABCDE1234F" }
      allow(DhanHQ::Models::Profile).to receive(:fetch).and_return(profile_data)

      response = send_request("resources/read", { uri: "dhanhq://account/profile" })

      content = response.dig("result", "contents").first
      expect(content["uri"]).to eq("dhanhq://account/profile")
      expect(content["mimeType"]).to eq("application/json")
      expect(JSON.parse(content["text"])).to include("client_id" => "test_client")
    end

    it "reads funds resource" do
      funds_data = double("Funds", available_balance: 100_000, attributes: { available_balance: 100_000 })
      allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(funds_data)

      response = send_request("resources/read", { uri: "dhanhq://account/funds" })

      expect(response.dig("result", "contents").first["uri"]).to eq("dhanhq://account/funds")
    end

    it "reads capabilities resource" do
      allow(DhanHQ::Agent::ToolRegistry).to receive(:capabilities).and_return({ version: "1.0.0", tool_count: 12 })

      response = send_request("resources/read", { uri: "dhanhq://market/capabilities" })

      expect(response.dig("result", "contents").first["uri"]).to eq("dhanhq://market/capabilities")
    end

    it "returns error for unknown resource" do
      response = send_request("resources/read", { uri: "dhanhq://unknown" })

      expect(response["error"]).not_to be_nil
    end
  end

  describe "prompts/list" do
    it "returns prompt definitions" do
      response = send_request("prompts/list")

      expect(response["id"]).to eq(1)
      prompts = response.dig("result", "prompts")
      expect(prompts).to be_an(Array)
      expect(prompts).not_to be_empty

      names = prompts.map { |p| p["name"] }
      expect(names).to include("portfolio_summary", "market_analysis", "risk_report", "order_preview", "suggest_strategy")
    end

    it "includes arguments for order_preview prompt" do
      response = send_request("prompts/list")
      prompts = response.dig("result", "prompts")
      order_preview = prompts.find { |p| p["name"] == "order_preview" }

      expect(order_preview["arguments"]).to be_an(Array)
      expect(order_preview["arguments"].map { |a| a["name"] }).to include("transaction_type", "security_id")
    end
  end

  describe "prompts/get" do
    it "returns portfolio_summary prompt" do
      allow(DhanHQ::Models::Holding).to receive(:all).and_return([])
      allow(DhanHQ::Models::Position).to receive(:all).and_return([])
      allow(DhanHQ::Models::Funds).to receive(:fetch).and_return(
        double("funds",
               available_balance: 100_000,
               to_prompt: "Funds: 100000")
      )

      response = send_request("prompts/get", { name: "portfolio_summary" })

      expect(response.dig("result", "messages")).to be_an(Array)
      expect(response.dig("result", "messages").first.dig("content", "text")).to include("Portfolio Summary")
    end

    it "returns risk_report prompt" do
      allow(DhanHQ::Models::Position).to receive(:all).and_return([])

      response = send_request("prompts/get", { name: "risk_report" })

      expect(response.dig("result", "messages")).to be_an(Array)
    end

    it "returns error for unknown prompt" do
      response = send_request("prompts/get", { name: "nonexistent" })

      expect(response["error"]).not_to be_nil
    end
  end

  describe "error handling" do
    it "returns error for unknown methods" do
      response = send_request("unknown_method")

      expect(response["error"]).not_to be_nil
      expect(response.dig("error", "code")).to eq(-32_000)
    end

    it "handles malformed JSON without raising" do
      input.puts("not json")
      input.rewind
      expect { server.run }.not_to raise_error
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
