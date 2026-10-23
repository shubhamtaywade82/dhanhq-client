# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Auth::TokenGenerator do
  subject(:generator) { described_class.new }

  let(:token_data) do
    {
      "dhanClientId" => "CLIENT123",
      "accessToken" => "tok_abc",
      "expiryTime" => (Time.now + 86_400).iso8601
    }
  end
  let(:token_response) { DhanHQ::Models::TokenResponse.new(token_data) }

  describe "#generate with explicit totp" do
    before do
      allow(DhanHQ::Auth).to receive(:generate_access_token).and_return(token_data)
    end

    it "delegates to Auth.generate_access_token and wraps result in TokenResponse" do
      result = generator.generate(dhan_client_id: "CLIENT123", pin: "1234", totp: "654321")

      expect(DhanHQ::Auth).to have_received(:generate_access_token).with(
        dhan_client_id: "CLIENT123",
        pin: "1234",
        totp: "654321"
      )
      expect(result).to be_a(DhanHQ::Models::TokenResponse)
      expect(result.access_token).to eq("tok_abc")
    end

    it "strips whitespace from the totp before using it" do
      generator.generate(dhan_client_id: "CLIENT123", pin: "1234", totp: "  654321  ")

      expect(DhanHQ::Auth).to have_received(:generate_access_token).with(
        hash_including(totp: "654321")
      )
    end
  end

  describe "#generate with totp_secret" do
    before do
      allow(DhanHQ::Auth).to receive(:generate_totp).with("MYSECRET").and_return("123456")
      allow(DhanHQ::Auth).to receive(:generate_access_token).and_return(token_data)
    end

    it "resolves the TOTP from the secret before calling generate_access_token" do
      generator.generate(dhan_client_id: "CLIENT123", pin: "1234", totp_secret: "MYSECRET")

      expect(DhanHQ::Auth).to have_received(:generate_totp).with("MYSECRET")
      expect(DhanHQ::Auth).to have_received(:generate_access_token).with(
        hash_including(totp: "123456")
      )
    end

    it "prefers explicit totp over totp_secret when both are provided" do
      generator.generate(
        dhan_client_id: "CLIENT123", pin: "1234",
        totp: "999999", totp_secret: "MYSECRET"
      )

      expect(DhanHQ::Auth).not_to have_received(:generate_totp)
      expect(DhanHQ::Auth).to have_received(:generate_access_token).with(
        hash_including(totp: "999999")
      )
    end
  end

  describe "#generate with neither totp nor totp_secret" do
    it "raises ArgumentError" do
      expect do
        generator.generate(dhan_client_id: "CLIENT123", pin: "1234")
      end.to raise_error(ArgumentError, /totp.*totp_secret/i)
    end

    it "raises ArgumentError when both are blank strings" do
      expect do
        generator.generate(dhan_client_id: "CLIENT123", pin: "1234", totp: "  ", totp_secret: "")
      end.to raise_error(ArgumentError)
    end
  end
end
