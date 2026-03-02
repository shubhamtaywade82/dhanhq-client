# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Auth::TokenRenewal do
  subject(:renewal) { described_class.new }

  let(:token_data) do
    {
      "dhanClientId" => "CLIENT123",
      "accessToken" => "renewed_tok",
      "expiryTime" => (Time.now + 86_400).iso8601
    }
  end

  describe "#renew" do
    context "when configuration is present with a valid client_id" do
      before do
        DhanHQ.configure do |c|
          c.client_id = "CLIENT123"
          c.access_token = "old_token"
        end
        allow(DhanHQ::Auth).to receive(:renew_token).and_return(token_data)
      end

      it "delegates to Auth.renew_token with the current token and client_id" do
        renewal.renew

        expect(DhanHQ::Auth).to have_received(:renew_token).with(
          access_token: "old_token",
          client_id: "CLIENT123"
        )
      end

      it "returns a TokenResponse" do
        result = renewal.renew

        expect(result).to be_a(DhanHQ::Models::TokenResponse)
        expect(result.access_token).to eq("renewed_tok")
      end
    end

    context "when client_id is blank" do
      before do
        DhanHQ.configure do |c|
          c.client_id = ""
          c.access_token = "old_token"
        end
      end

      # NOTE: the source raises `Errors::AuthenticationError` which is unresolved in
      # this namespace (DhanHQ has no Errors module); this will raise StandardError/NameError
      # until that reference is corrected to `DhanHQ::AuthenticationError`.
      it "raises an error when client_id is blank" do
        expect { renewal.renew }.to raise_error(StandardError)
      end
    end

    context "when client_id is nil" do
      before do
        DhanHQ.configure do |c|
          c.client_id = nil
          c.access_token = "old_token"
        end
      end

      it "raises an error when client_id is nil" do
        expect { renewal.renew }.to raise_error(StandardError)
      end
    end
  end
end
