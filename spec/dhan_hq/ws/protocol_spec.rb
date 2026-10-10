# frozen_string_literal: true

require "spec_helper"

# The executable WebSocket wire contract: binary fixtures are PACKED FROM the
# manifest (contracts/dhanhq/ws_protocol.yml) and then run through the real
# decoders. Manifest and decoders are therefore locked together — a change to
# either side without the other is a failing test, not a production outage.
# This is the structural prevention of the F1–F7 bug class (wrong request
# codes, wrong endianness, dropped packets, wrong header widths).
RSpec.describe DhanHQ::WS::Protocol do
  let(:parser) { DhanHQ::WS::WebsocketPacketParser }

  def pack_field(field, value)
    case field["type"]
    when "uint8"   then [value].pack("C")
    when "uint16"  then [value].pack("v")
    when "int16"   then [value].pack("s<")
    when "uint32"  then [value].pack("V")
    when "int32"   then [value].pack("l<")
    when "float32" then [value].pack("e")
    when "float64" then [value].pack("E")
    else raise "unhandled manifest type #{field["type"]}"
    end
  end

  # Builds a full frame (header + payload + arrays) from the manifest layout.
  def build_frame(packet_name, payload:, segment: 1, security_id: 1333, arrays: {})
    payload = payload.transform_keys(&:to_s)
    layout = described_class.packet(packet_name)
    buffer = ("\x00" * layout["size"]).b

    described_class.response_header["fields"].each do |field|
      value = case field["name"]
              when "feed_response_code" then layout["code"]
              when "message_length" then layout["size"]
              when "exchange_segment" then segment
              when "security_id" then security_id
              end
      buffer[field["offset"], pack_field(field, value).bytesize] = pack_field(field, value)
    end

    Array(layout["fields"]).each do |field|
      next unless payload.key?(field["name"])

      buffer[field["offset"], pack_field(field, payload[field["name"]]).bytesize] =
        pack_field(field, payload[field["name"]])
    end

    Array(layout["arrays"]).each do |array|
      levels = arrays.fetch(array["name"])
      levels.each_with_index do |level, index|
        level = level.transform_keys(&:to_s)
        base = array["offset"] + (index * array["each"])
        array["fields"].each do |field|
          packed = pack_field(field, level.fetch(field["name"]))
          buffer[base + field["offset"], packed.bytesize] = packed
        end
      end
    end

    buffer
  end

  shared_examples "a decoded packet" do |packet_name, expected_kind|
    it "decodes #{packet_name} bytes packed from the manifest" do
      frame = build_frame(packet_name, payload: payload, arrays: arrays)
      decoded = DhanHQ::WS::Decoder.decode(frame)

      expect(decoded).not_to be_nil
      expect(decoded[:kind]).to eq(expected_kind)
      expect(decoded[:segment]).to eq("NSE_EQ")
      expect(decoded[:security_id]).to eq("1333")
      expected.each do |key, value|
        expect(decoded[key]).to eq(value)
      end
    end
  end

  describe "header" do
    it "matches the BinData header field-for-field" do
      fields = described_class.response_header["fields"]

      expect(fields.map { |f| f["name"] }).to eq(%w[feed_response_code message_length exchange_segment security_id])
      expect(fields.map { |f| f["offset"] }).to eq([0, 1, 3, 4])
      expect(fields.map { |f| f["type"] }).to eq(%w[uint8 uint16 uint8 int32])
    end
  end

  describe "packet layouts round-trip through the decoders" do
    let(:payload) { {} }
    let(:arrays) { {} }

    context "with a ticker frame" do
      let(:payload) { { ltp: 2450.5, ltt: 1_736_000_000 } }
      let(:expected) { { ltp: 2450.5, ts: 1_736_000_000 } }

      it_behaves_like "a decoded packet", :ticker, :ticker
    end

    context "with an index frame" do
      let(:payload) do
        { latest: 24_500.5, open: 24_400.0, close: 24_600.0, high: 24_650.25, low: 24_350.75,
          update_time: 1_736_000_100 }
      end
      let(:expected) do
        { ltp: 24_500.5, latest: 24_500.5, day_open: 24_400.0, day_close: 24_600.0,
          day_high: 24_650.25, day_low: 24_350.75, ts: 1_736_000_100 }
      end

      it_behaves_like "a decoded packet", :index, :index
    end

    context "with a quote frame" do
      let(:payload) do
        { ltp: 2450.5, last_trade_qty: 75, ltt: 1_736_000_000, atp: 2445.25, volume: 1_234_567,
          total_sell_qty: 555_000, total_buy_qty: 444_000, day_open: 2440.0, day_close: 2447.0,
          day_high: 2460.0, day_low: 2435.0 }
      end
      let(:expected) do
        { ltp: 2450.5, ts: 1_736_000_000, atp: 2445.25, vol: 1_234_567,
          ts_buy_qty: 444_000, ts_sell_qty: 555_000, day_open: 2440.0, day_close: 2447.0,
          day_high: 2460.0, day_low: 2435.0 }
      end

      it_behaves_like "a decoded packet", :quote, :quote
    end

    context "with an oi frame" do
      let(:payload) { { open_interest: 98_765 } }
      let(:expected) { { oi: 98_765 } }

      it_behaves_like "a decoded packet", :oi, :oi
    end

    context "with a prev_close frame" do
      let(:payload) { { prev_close: 2433.75, oi_prev: 12_345 } }
      let(:expected) { { prev_close: 2433.75, oi_prev: 12_345 } }

      it_behaves_like "a decoded packet", :prev_close, :prev_close
    end

    context "with a market_status frame" do
      it "decodes the header-only frame" do
        frame = build_frame(:market_status, payload: {})

        expect(DhanHQ::WS::Decoder.decode(frame)).to include(kind: :market_status, security_id: "1333")
      end
    end

    context "with a disconnect frame" do
      let(:payload) { { disconnection_code: 805 } }

      it "decodes the LE uint16 code and reports the manifest reason" do
        frame = build_frame(:disconnect, payload: payload)

        expect(DhanHQ::WS::Decoder.decode(frame)).to be_nil # disconnect logs and returns nil
        expect(described_class.disconnect_reason(805)).to eq("Connection limit exceeded")
        pkt = parser.new(frame).parse
        expect(pkt[:disconnection_code]).to eq(805)
      end
    end

    context "with a depth (5-level) frame" do
      let(:payload) { { ltp: 2450.5 } }
      let(:arrays) do
        { "market_depth" => Array.new(5) do |i|
          { bid_quantity: 100 + i, ask_quantity: 200 + i, no_of_bid_orders: 3 + i,
            no_of_ask_orders: 4 + i, bid_price: 2449.5 + i, ask_price: 2451.5 + i }
        end }
      end
      let(:expected) { { ltp: 2450.5, bid: 2449.5, ask: 2451.5, bid_qty: 100, ask_qty: 200 } }

      it_behaves_like "a decoded packet", :depth, :depth
    end

    context "with a full frame" do
      let(:payload) do
        { ltp: 2450.5, last_trade_qty: 75, ltt: 1_736_000_000, atp: 2445.25, volume: 1_234_567,
          total_sell_qty: 555_000, total_buy_qty: 444_000, open_interest: 9_999_999,
          highest_oi: 10_500_000, lowest_oi: 9_500_000, day_open: 2440.0, day_close: 2447.0,
          day_high: 2460.0, day_low: 2435.0 }
      end
      let(:arrays) do
        { "market_depth" => Array.new(5) do |i|
          { bid_quantity: 100 + i, ask_quantity: 200 + i, no_of_bid_orders: 3 + i,
            no_of_ask_orders: 4 + i, bid_price: 2449.5 + i, ask_price: 2451.5 + i }
        end }
      end
      let(:expected) do
        { ltp: 2450.5, ts: 1_736_000_000, atp: 2445.25, vol: 1_234_567,
          ts_buy_qty: 444_000, ts_sell_qty: 555_000, oi: 9_999_999,
          oi_high: 10_500_000, oi_low: 9_500_000, day_open: 2440.0, day_close: 2447.0,
          day_high: 2460.0, day_low: 2435.0, bid: 2449.5, ask: 2451.5, bid_qty: 100, ask_qty: 200 }
      end

      it_behaves_like "a decoded packet", :full, :full
    end
  end

  describe "request codes" do
    it "serves SUB_CODES/UNSUB_CODES from the manifest" do
      expect(DhanHQ::WS::Connection::SUB_CODES).to eq(ticker: 15, quote: 17, full: 21)
      expect(DhanHQ::WS::Connection::UNSUB_CODES).to eq(ticker: 16, quote: 18, full: 22)
    end

    it "keeps unsubscribe = subscribe + 1 for every instrument family" do
      # The annexure's documented rule of thumb — and its one exception: the
      # Index family is reversed in the published table (13 = unsubscribe,
      # 14 = subscribe), encoded verbatim in the manifest.
      %i[ticker quote depth full market_depth].each do |family|
        sub = described_class.request_code(family, :subscribe)
        unsub = described_class.request_code(family, :unsubscribe)

        expect(unsub).to eq(sub + 1), "#{family}: #{unsub} != #{sub} + 1"
      end

      expect(described_class.request_code(:index, :subscribe)).to eq(14)
      expect(described_class.request_code(:index, :unsubscribe)).to eq(13)
    end

    it "never offers 12 as an unsubscribe code" do
      %i[index ticker quote depth full market_depth].each do |family|
        expect(described_class.request_code(family, :unsubscribe))
          .not_to eq(described_class.disconnect_request_code)
      end
    end

    it "keeps the market-depth client on the manifest codes" do
      client_codes = DhanHQ::WS::MarketDepth::Client::SUBSCRIBE_REQUEST_CODE
      expect(client_codes).to eq(23)
      expect(DhanHQ::WS::MarketDepth::Client::UNSUBSCRIBE_REQUEST_CODE).to eq(24)
    end
  end

  describe "exchange segments" do
    it "serves Segments from the manifest" do
      expect(DhanHQ::WS::Segments::STRING_TO_CODE).to eq(described_class.exchange_segments)
      expect(described_class.exchange_segments).to include(
        "IDX_I" => 0, "NSE_EQ" => 1, "NSE_FNO" => 2, "NSE_CURRENCY" => 3,
        "BSE_EQ" => 4, "MCX_COMM" => 5, "BSE_CURRENCY" => 7, "BSE_FNO" => 8
      )
      expect(described_class.exchange_segments).not_to have_key("NSE_COMM_X")
    end
  end

  describe "response codes" do
    it "keeps the decoder's kind map in sync with the manifest" do
      feed_kind = DhanHQ::WS::Decoder::FEED_KIND
      # :depth_bid / :depth_ask are the decoder's names for the FMD socket's
      # bid (41) and ask (51) frames.
      manifest_codes = {
        "index" => 1, "ticker" => 2, "depth" => 3, "quote" => 4, "oi" => 5,
        "prev_close" => 6, "market_status" => 7, "full" => 8,
        "fmd_bid" => 41, "fmd_ask" => 51, "disconnect" => 50
      }
      manifest_codes.each do |name, code|
        expected = name.start_with?("fmd_") ? :"depth_#{name.delete_prefix("fmd_")}" : name.to_sym
        expect(feed_kind).to include(code => expected)
      end
    end
  end

  describe "full market depth" do
    let(:fmd_header) { described_class.full_market_depth.fetch("header") }
    let(:row_layout) { described_class.full_market_depth.fetch("row") }

    def build_fmd_frame(code, security_id, levels, segment: 1)
      header_size = fmd_header.fetch("size")
      body = levels.map do |level|
        level = level.transform_keys(&:to_s)
        row = ("\x00" * row_layout.fetch("size")).b
        row_layout.fetch("fields").each do |field|
          packed = pack_field(field, level.fetch(field["name"]))
          row[field["offset"], packed.bytesize] = packed
        end
        row
      end.join

      header = ("\x00" * header_size).b
      fmd_header.fetch("fields").each do |field|
        value = case field["name"]
                when "message_length" then header_size + body.bytesize
                when "feed_response_code" then code
                when "exchange_segment" then segment
                when "security_id" then security_id
                when "rows" then levels.size
                end
        packed = pack_field(field, value)
        header[field["offset"], packed.bytesize] = packed
      end

      header + body
    end

    it "round-trips a stacked 20-level bid/ask pair through MarketDepth::Decoder" do
      levels = Array.new(20) { |i| { price: 100.5 + i, quantity: 1_000 + i, orders: 2 + i } }
      bid_frame = build_fmd_frame(41, 1333, levels)
      ask_frame = build_fmd_frame(51, 1333, levels)

      frames = DhanHQ::WS::MarketDepth::Decoder.new.decode(bid_frame + ask_frame)

      expect(frames.size).to eq(2) # message_length splitting, not a merged blob
      expect(frames[0][:side]).to eq(:bid)
      expect(frames[0][:security_id]).to eq("1333")
      expect(frames[0][:levels].first).to include(price: 100.5, quantity: 1000, orders: 2)
      expect(frames[0][:levels].last).to include(price: 119.5, quantity: 1019, orders: 21)
      expect(frames[1][:side]).to eq(:ask)
    end

    it "documents the 332/3212-byte frame geometry" do
      frame_sizes = described_class.full_market_depth.fetch("frame_sizes")
      row_size = row_layout.fetch("size")
      header_size = fmd_header.fetch("size")

      expect(frame_sizes.fetch("twenty_level")).to eq(header_size + (20 * row_size))
      expect(frame_sizes.fetch("twohundred_level")).to eq(header_size + (200 * row_size))
    end
  end
end
