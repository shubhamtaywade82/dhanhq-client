# frozen_string_literal: true

RSpec.describe DhanHQ::Auth do
  let(:renew_url) { "https://api.dhan.co/v2/RenewToken" }
  let(:generate_url) { %r{\Ahttps://auth\.dhan\.co/app/generateAccessToken\?} }
  let(:token_body) do
    { dhanClientId: "1100", accessToken: "new-jwt", expiryTime: "2026-10-12T09:30:00" }.to_json
  end

  describe ".renew_token" do
    def renew = described_class.renew_token(access_token: "old-jwt", client_id: "1100")

    it "GETs /v2/RenewToken with the token headers and returns the parsed body" do
      stub = stub_request(:get, renew_url)
             .with(headers: { "access-token" => "old-jwt", "dhanClientId" => "1100" })
             .to_return(status: 200, body: token_body, headers: { "Content-Type" => "application/json" })

      expect(renew).to include("accessToken" => "new-jwt", "expiryTime" => "2026-10-12T09:30:00")
      expect(stub).to have_been_requested
    end

    it "parses the body even when the response is not labelled as JSON" do
      stub_request(:get, renew_url).to_return(status: 200, body: token_body)

      expect(renew["accessToken"]).to eq("new-jwt")
    end

    it "raises InvalidAuthenticationError when Dhan rejects the token" do
      stub_request(:get, renew_url).to_return(status: 401, body: { errorMessage: "Token expired" }.to_json)

      expect { renew }.to raise_error(DhanHQ::InvalidAuthenticationError, /RenewToken failed: 401 Token expired/)
    end

    it "raises RateLimitError on 429 so callers can back off instead of re-authenticating" do
      stub_request(:get, renew_url).to_return(status: 429, body: "")

      expect { renew }.to raise_error(DhanHQ::RateLimitError)
    end

    it "raises InternalServerError on 5xx" do
      stub_request(:get, renew_url).to_return(status: 503, body: { errorMessage: "down" }.to_json)

      expect { renew }.to raise_error(DhanHQ::InternalServerError, /503 down/)
    end

    it "raises NetworkError on timeouts" do
      stub_request(:get, renew_url).to_timeout

      expect { renew }.to raise_error(DhanHQ::NetworkError, /RenewToken/)
    end

    it "keeps the parsed error payload on the raised error" do
      stub_request(:get, renew_url).to_return(status: 401, body: { errorMessage: "Token expired" }.to_json)

      expect { renew }.to raise_error(DhanHQ::InvalidAuthenticationError) { |error|
        expect(error.response_body).to eq("errorMessage" => "Token expired")
      }
    end
  end

  describe ".generate_access_token" do
    def generate = described_class.generate_access_token(dhan_client_id: "1100", pin: "1234", totp: "654321")

    it "POSTs to auth.dhan.co/app/generateAccessToken with credentials as query params" do
      stub = stub_request(:post, "https://auth.dhan.co/app/generateAccessToken")
             .with(query: { dhanClientId: "1100", pin: "1234", totp: "654321" })
             .to_return(status: 200, body: token_body)

      expect(generate["accessToken"]).to eq("new-jwt")
      expect(stub).to have_been_requested
    end

    it "raises InvalidAuthenticationError for a wrong PIN or TOTP" do
      stub_request(:post, generate_url).to_return(status: 400, body: { errorMessage: "Invalid TOTP" }.to_json)

      expect { generate }.to raise_error(DhanHQ::InvalidAuthenticationError, /GenerateAccessToken failed: 400 Invalid TOTP/)
    end
  end

  describe "connection timeouts" do
    it "bounds auth requests with the same defaults as the API client" do
      stub_request(:get, renew_url).to_return(status: 200, body: token_body)
      connection = nil
      allow(Faraday).to receive(:new).and_wrap_original do |original, *args, **kwargs, &block|
        connection = original.call(*args, **kwargs, &block)
      end

      described_class.renew_token(access_token: "old-jwt", client_id: "1100")

      expect(connection.options.open_timeout).to eq(10)
      expect(connection.options.timeout).to eq(30)
    end
  end

  describe "TokenRenewal integration" do
    it "returns a TokenResponse carrying the renewed token" do
      DhanHQ.configure do |config|
        config.client_id = "1100"
        config.access_token = "old-jwt"
      end
      stub_request(:get, renew_url).to_return(status: 200, body: token_body)

      expect(DhanHQ::Auth::TokenRenewal.new.renew.access_token).to eq("new-jwt")
    end
  end
end
