# frozen_string_literal: true

RSpec.describe DhanHQ::Resources::Edis do
  subject(:edis) { described_class.new }

  let(:client) { instance_double(DhanHQ::Client) }

  before do
    allow(DhanHQ::Client).to receive(:new).and_return(client)
    allow(client).to receive_messages(post: {}, get: {})
  end

  describe "#form" do
    it "posts to /edis/form with params" do
      edis.form(isin: "INE733E01010", qty: 1, exchange: "NSE", segment: "EQ", bulk: false)

      expect(client).to have_received(:post).with("/edis/form", anything)
    end
  end

  describe "#bulk_form" do
    it "posts to /edis/bulkform with params" do
      edis.bulk_form(exchange: "NSE", segment: "EQ", bulk: true)

      expect(client).to have_received(:post).with("/edis/bulkform", anything)
    end
  end

  describe "#tpin" do
    it "gets /edis/tpin" do
      edis.tpin

      expect(client).to have_received(:get).with("/edis/tpin", {})
    end
  end

  describe "#inquire" do
    it "gets /edis/inquire/{isin}" do
      edis.inquire("INE002A01018")

      expect(client).to have_received(:get).with("/edis/inquire/INE002A01018", {})
    end
  end
end
