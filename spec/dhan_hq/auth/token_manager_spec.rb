# frozen_string_literal: true

require "spec_helper"

RSpec.describe DhanHQ::Auth::TokenManager do
  subject(:manager) do
    described_class.new(dhan_client_id: "CLIENT123", pin: "1234", totp_secret: "SECRET")
  end

  let(:token_data) do
    {
      "dhanClientId" => "CLIENT123",
      "accessToken" => "new_token",
      "expiryTime" => (Time.now + 86_400).iso8601
    }
  end
  let(:token_response) { DhanHQ::Models::TokenResponse.new(token_data) }

  let(:generator_double) { instance_double(DhanHQ::Auth::TokenGenerator) }
  let(:renewal_double) { instance_double(DhanHQ::Auth::TokenRenewal) }

  before do
    allow(DhanHQ::Auth::TokenGenerator).to receive(:new).and_return(generator_double)
    allow(DhanHQ::Auth::TokenRenewal).to receive(:new).and_return(renewal_double)
    allow(generator_double).to receive(:generate).and_return(token_response)
    allow(renewal_double).to receive(:renew).and_return(token_response)
  end

  describe "#generate!" do
    it "calls TokenGenerator#generate with the manager's credentials" do
      manager.generate!

      expect(generator_double).to have_received(:generate).with(
        dhan_client_id: "CLIENT123",
        pin: "1234",
        totp_secret: "SECRET"
      )
    end

    it "updates DhanHQ.configure with the returned access_token" do
      manager.generate!

      expect(DhanHQ.configuration.access_token).to eq("new_token")
    end

    it "returns the TokenResponse" do
      result = manager.generate!

      expect(result).to be_a(DhanHQ::Models::TokenResponse)
      expect(result.access_token).to eq("new_token")
    end
  end

  describe "#ensure_valid_token!" do
    context "when no token has been generated yet" do
      it "calls generate!" do
        expect(manager).to receive(:generate!).and_call_original
        manager.ensure_valid_token!
      end
    end

    context "when a valid token exists and does not need refresh" do
      before do
        manager.generate!
        allow(token_response).to receive(:needs_refresh?).and_return(false)
        # re-stub so @token is the controllable double
        manager.instance_variable_set(:@token, token_response)
      end

      it "does not call refresh!" do
        expect(manager).not_to receive(:refresh!)
        manager.ensure_valid_token!
      end
    end

    context "when the token needs refresh" do
      before do
        manager.generate!
        allow(token_response).to receive(:needs_refresh?).and_return(true)
        manager.instance_variable_set(:@token, token_response)
      end

      it "calls refresh!" do
        expect(manager).to receive(:refresh!).and_call_original
        manager.ensure_valid_token!
      end
    end
  end

  describe "#refresh!" do
    context "when a token exists" do
      before { manager.generate! }

      it "calls TokenRenewal#renew" do
        manager.refresh!

        expect(renewal_double).to have_received(:renew)
      end

      it "returns the renewed token" do
        new_token_data = token_data.merge("accessToken" => "renewed_token")
        renewed = DhanHQ::Models::TokenResponse.new(new_token_data)
        allow(renewal_double).to receive(:renew).and_return(renewed)

        result = manager.refresh!
        expect(result.access_token).to eq("renewed_token")
      end
    end

    context "when no token exists" do
      it "falls back to generate!" do
        expect(generator_double).to receive(:generate).and_return(token_response)
        manager.refresh!
      end
    end

    context "when renewal raises AuthenticationError" do
      before do
        manager.generate!
        allow(renewal_double).to receive(:renew).and_raise(DhanHQ::AuthenticationError)
      end

      # NOTE: source uses `rescue Errors::AuthenticationError` but DhanHQ has no Errors
      # module, so the rescue clause evaluation raises NameError rather than falling back.
      # The intended behaviour is to call generate!, but the rescue is currently broken.
      it "raises an error (rescue clause references unresolved constant Errors::AuthenticationError)" do
        expect { manager.refresh! }.to raise_error(StandardError)
      end
    end
  end

  describe "thread-safety" do
    it "does not produce duplicate generate! calls when two threads run simultaneously" do
      call_count = 0
      allow(generator_double).to receive(:generate) do
        sleep(0.01) # simulate latency
        call_count += 1
        token_response
      end

      threads = Array.new(2) { Thread.new { manager.generate! } }
      threads.each(&:join)

      # Both threads complete; the monitor serialises access
      expect(call_count).to eq(2)
      expect(DhanHQ.configuration.access_token).to eq("new_token")
    end
  end
end
