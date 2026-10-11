# frozen_string_literal: true

require "yaml"

RSpec.describe "docs/ws_lifecycle.asyncapi.yml" do
  subject(:doc) { YAML.safe_load_file(path, aliases: true) }

  let(:path) { File.expand_path("../../../docs/ws_lifecycle.asyncapi.yml", __dir__) }
  let(:manifest) { DhanHQ::WS::Protocol.manifest }

  it "is a valid AsyncAPI 2.6 document with the manifest version" do
    expect(doc["asyncapi"]).to eq("2.6.0")
    expect(doc.dig("info", "version")).to eq(manifest.dig("meta", "version").to_s)
    expect(doc.dig("info", "title")).to include("DhanHQ Live Market Feed")
  end

  # The document is generated from ws_protocol.yml; a stale committed copy
  # would silently describe a protocol that no longer exists. Regeneration
  # must be byte-identical — the asyncapi analogue of metadata parity.
  it "matches a fresh regeneration byte-for-byte (no drift)" do
    DhanHQ::WS::Protocol.reset!
    generated = DhanHQ::Contract::Generator.send(:asyncapi_source)
    DhanHQ::WS::Protocol.reset!
    expect(generated).to eq(File.read(path, encoding: "UTF-8"))
  end

  describe "servers" do
    it "declares every socket from the manifest connection section" do
      conn = manifest.fetch("connection")
      expect(doc["servers"].keys).to contain_exactly("market_feed", "twenty_depth", "two_hundred_depth")
      expect(doc.dig("servers", "market_feed", "url")).to eq(conn.fetch("v2_url"))
      expect(doc.dig("servers", "market_feed", "protocol")).to eq("wss")
      expect(doc.dig("servers", "twenty_depth", "url")).to eq(conn.dig("market_depth_urls", "twenty_level"))
      expect(doc.dig("servers", "two_hundred_depth", "url")).to eq(conn.dig("market_depth_urls", "twohundred_level"))
      expect(doc.dig("servers", "market_feed", "bindings", "ws", "query")).to include("version" => 2, "authType" => 2)
    end
  end

  describe "client command messages" do
    let(:messages) { doc.dig("components", "messages") }

    it "carries one subscribe and one unsubscribe message per request family" do
      %w[subscribe unsubscribe].each do |direction|
        families = manifest.fetch("request_codes").fetch(direction).keys
        families.each do |family|
          expect(messages).to have_key("#{direction}#{pascal(family)}"),
                              "missing #{direction} message for the #{family} family"
        end
      end
    end

    it "stamps each command with the manifest request code" do
      manifest.fetch("request_codes").slice("subscribe", "unsubscribe").each do |direction, families|
        families.each do |family, code|
          payload = messages.fetch("#{direction}#{pascal(family)}").fetch("payload")
          expect(payload.dig("properties", "requestCode", "const")).to eq(code),
                                                                       "#{direction}/#{family}: requestCode drift"
        end
      end
    end

    it "keeps the index-family unsubscribe exception (14/13) encoded in the document" do
      expect(messages.fetch("subscribeIndex").dig("payload", "properties", "requestCode", "const")).to eq(14)
      expect(messages.fetch("unsubscribeIndex").dig("payload", "properties", "requestCode", "const")).to eq(13)
    end

    it "describes the whole-connection disconnect frame (RequestCode 12)" do
      expect(messages.fetch("disconnectFeed").dig("payload", "properties", "requestCode", "const"))
        .to eq(manifest.fetch("request_codes").fetch("disconnect"))
    end

    it "caps the instruments array at the per-message limit" do
      limit = manifest.dig("connection", "max_instruments_per_json_message")
      expect(messages.fetch("subscribeTicker").dig("payload", "properties", "instruments", "maxItems")).to eq(limit)
    end
  end

  describe "server packet messages" do
    let(:messages) { doc.dig("components", "messages") }

    it "carries one message per manifest packet with the byte layout verbatim" do
      manifest.fetch("packets").each do |packet, layout|
        message = messages.fetch("feed#{pascal(packet)}")
        expect(message.dig("payload", "x-dhan-struct")).to eq(layout),
                                                           "packet #{packet}: x-dhan-struct must equal the manifest layout"
      end
    end

    it "carries the FMD frame geometry with limits" do
      fmd = messages.fetch("feedFullMarketDepth").dig("payload", "x-dhan-struct")
      expect(fmd).to eq(manifest.fetch("full_market_depth"))
    end

    it "documents every disconnect code as a message example" do
      examples = messages.fetch("feedDisconnect").fetch("examples")
      codes = examples.map { |e| e.dig("payload", "disconnection_code") }
      expect(codes).to eq(manifest.fetch("disconnect_codes").keys.map(&:to_i))
    end

    it "references every packet message from the marketfeed channel" do
      one_of = doc.dig("channels", "marketfeed", "subscribe", "message", "oneOf")
      refs = one_of.map { |m| m["$ref"].split("/").last }
      expect(refs).to eq(manifest.fetch("packets").keys.map { |p| "feed#{pascal(p)}" })
    end
  end

  describe "x-dhan-lifecycle" do
    subject(:lifecycle) { doc.fetch("x-dhan-lifecycle") }

    it "mirrors the manifest connection section plus disconnect codes" do
      expect(lifecycle).to eq(manifest.fetch("connection").merge("disconnect_codes" => manifest.fetch("disconnect_codes")))
    end

    it "keeps the operational facts integrators rely on" do
      expect(lifecycle.fetch("server_ping_interval_seconds")).to eq(10)
      expect(lifecycle.fetch("dead_after_silence_seconds")).to eq(40)
      expect(lifecycle.fetch("max_connections_per_user")).to eq(5)
      expect(lifecycle.fetch("max_instruments_per_connection")).to eq(5000)
      expect(lifecycle.fetch("disconnect_codes").keys.map(&:to_i)).to include(805, 809)
    end
  end

  def pascal(snake)
    snake.to_s.split("_").map(&:capitalize).join
  end
end
