# frozen_string_literal: true

RSpec.describe DhanHQ::Models::Postback do
  describe ".parse" do
    context "with a JSON string" do
      it "parses the payload into a Postback instance" do # rubocop:disable RSpec/MultipleExpectations
        json = '{"orderId":"123456","orderStatus":"TRADED","transactionType":"BUY","quantity":10,"filledQty":10}'

        postback = described_class.parse(json)

        expect(postback).to be_a(described_class)
        expect(postback.order_id).to eq("123456")
        expect(postback.order_status).to eq("TRADED")
        expect(postback.transaction_type).to eq("BUY")
        expect(postback.quantity).to eq(10)
        expect(postback.filled_qty).to eq(10)
      end
    end

    context "with a Hash" do
      it "normalizes camelCase keys" do
        hash = { "orderId" => "789", "orderStatus" => "REJECTED", "omsErrorDescription" => "Insufficient margin" }

        postback = described_class.parse(hash)

        expect(postback.order_id).to eq("789")
        expect(postback.order_status).to eq("REJECTED")
        expect(postback.oms_error_description).to eq("Insufficient margin")
      end
    end

    context "with snake_case keys" do
      it "accepts snake_case hash" do
        hash = { order_id: "111", order_status: "PENDING" }

        postback = described_class.parse(hash)

        expect(postback.order_id).to eq("111")
        expect(postback.order_status).to eq("PENDING")
      end
    end

    it "raises for unsupported types" do
      expect { described_class.parse(42) }.to raise_error(ArgumentError, /Expected String or Hash/)
    end
  end

  describe "status predicates" do
    it "#traded? returns true for TRADED status" do
      postback = described_class.new({ "orderStatus" => "TRADED" }, skip_validation: true)
      expect(postback.traded?).to be(true)
      expect(postback.rejected?).to be(false)
    end

    it "#rejected? returns true for REJECTED status" do
      postback = described_class.new({ "orderStatus" => "REJECTED" }, skip_validation: true)
      expect(postback.rejected?).to be(true)
      expect(postback.traded?).to be(false)
    end

    it "#pending? returns true for PENDING status" do
      postback = described_class.new({ "orderStatus" => "PENDING" }, skip_validation: true)
      expect(postback.pending?).to be(true)
    end

    it "#cancelled? returns true for CANCELLED status" do
      postback = described_class.new({ "orderStatus" => "CANCELLED" }, skip_validation: true)
      expect(postback.cancelled?).to be(true)
    end
  end

  describe "#validation_contract" do
    it "returns nil" do
      postback = described_class.new({}, skip_validation: true)
      expect(postback.validation_contract).to be_nil
    end
  end
end
