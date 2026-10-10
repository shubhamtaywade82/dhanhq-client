# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Contract::SchemaValidator do
  let(:place_order) { DhanHQ::Contract::Registry.operation("placeorder") }
  let(:multi_order) { DhanHQ::Contract::Registry.operation("placeMultiOrder") }
  let(:news_headline) { DhanHQ::Contract::Registry.operation("newsHeadline") }

  def valid_order_payload
    {
      transactionType: "BUY", exchangeSegment: "NSE_EQ", securityId: "1333",
      quantity: 1, productType: "CNC", orderType: "LIMIT", validity: "DAY",
      price: 100.0
    }
  end

  describe ".validate_request!" do
    it "accepts a schema-valid payload" do
      expect(described_class.validate_request!(place_order, valid_order_payload)).to be(true)
    end

    it "accepts symbol-keyed payloads (stringify before validating)" do
      expect(described_class.validate_request!(place_order, valid_order_payload)).to be(true)
    end

    it "accepts payloads carrying extra properties the schema does not list" do
      # The gem legitimately adds operational fields (injected dhanClientId,
      # injected correlationId) beyond the vendor schema's property list.
      expect(described_class.validate_request!(place_order, valid_order_payload.merge(extra: "x"))).to be(true)
    end

    it "raises on missing required fields" do
      expect { described_class.validate_request!(place_order, securityId: "1333") }
        .to raise_error(DhanHQ::ValidationError, /placeorder.*required/i)
    end

    it "raises on enum violations" do
      expect { described_class.validate_request!(place_order, valid_order_payload.merge(transactionType: "HOLD")) }
        .to raise_error(DhanHQ::ValidationError, /transactionType/)
    end

    it "raises on type violations" do
      expect { described_class.validate_request!(place_order, valid_order_payload.merge(quantity: "one")) }
        .to raise_error(DhanHQ::ValidationError, /quantity/)
    end

    it "validates nested $refs (multi-order legs)" do
      payload = {
        dhanClientId: "1000000001",
        orders: [{
          transactionType: "BUY", exchangeSegment: "NSE_EQ", securityId: "1333",
          quantity: 1, sequence: "1"
        }]
      }
      expect(described_class.validate_request!(multi_order, payload)).to be(true)

      payload[:orders].first[:transactionType] = "SIDEWAYS"
      expect { described_class.validate_request!(multi_order, payload) }
        .to raise_error(DhanHQ::ValidationError, /transactionType/)
    end

    it "validates the payload as it will hit the wire, after dhanClientId injection" do
      payload = { categories: ["TECHNOLOGY"], limit: 10 }.merge("dhanClientId" => "1000000001")
      expect(described_class.validate_request!(news_headline, payload)).to be(true)
    end

    it "is a no-op for operations without a request schema" do
      fundlimit = DhanHQ::Contract::Registry.operation("fundlimit")

      expect(described_class.validate_request!(fundlimit, anything)).to be_nil
      expect(described_class.validate_request!(nil, anything)).to be_nil
    end
  end

  describe ".response_errors" do
    it "returns [] for operations without response schemas" do
      ltp = DhanHQ::Contract::Registry.operation("marketfeedLTP")

      expect(described_class.response_errors(ltp, { "data" => {} })).to eq([])
    end
  end

  describe "overlay-reconciled enums" do
    it "validates against the annexure segment set, not the vendor spec's" do
      # The vendor spec's enum omits IDX_I / NSE_CURRENCY / BSE_CURRENCY;
      # overlay 0005 reconciles it with the published annexure table.
      payload = valid_order_payload.merge(exchangeSegment: "IDX_I")

      expect(described_class.validate_request!(place_order, payload)).to be(true)
    end
  end
end
