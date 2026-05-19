# frozen_string_literal: true

RSpec.describe DhanHQ::Utils::NetworkInspector do
  before { described_class.reset_cache! }
  after  { described_class.reset_cache! }

  describe ".public_ipv4" do
    context "when the ipify endpoint is reachable" do
      before do
        stub_request(:get, "https://api.ipify.org")
          .to_return(status: 200, body: "122.171.22.40")
      end

      it "returns the trimmed IPv4 address" do
        expect(described_class.public_ipv4).to eq("122.171.22.40")
      end

      it "caches the result on subsequent calls" do
        described_class.public_ipv4
        described_class.public_ipv4
        expect(a_request(:get, "https://api.ipify.org")).to have_been_made.once
      end
    end

    context "when the ipify endpoint is unreachable" do
      before { stub_request(:get, "https://api.ipify.org").to_raise(SocketError) }

      it "returns 'unknown'" do
        expect(described_class.public_ipv4).to eq("unknown")
      end
    end
  end

  describe ".public_ipv6" do
    context "when the ipify64 endpoint is reachable" do
      before do
        stub_request(:get, "https://api64.ipify.org")
          .to_return(status: 200, body: "2401:4900:894c:8448:1da9:27f1:48e7:61be")
      end

      it "returns the trimmed IPv6 address" do
        expect(described_class.public_ipv6).to eq("2401:4900:894c:8448:1da9:27f1:48e7:61be")
      end

      it "caches the result on subsequent calls" do
        described_class.public_ipv6
        described_class.public_ipv6
        expect(a_request(:get, "https://api64.ipify.org")).to have_been_made.once
      end
    end

    context "when the ipify64 endpoint is unreachable" do
      before { stub_request(:get, "https://api64.ipify.org").to_raise(SocketError) }

      it "returns 'unknown'" do
        expect(described_class.public_ipv6).to eq("unknown")
      end
    end
  end

  describe ".hostname" do
    it "returns a non-empty string" do
      result = described_class.hostname
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end
  end

  describe ".environment" do
    context "when RAILS_ENV is set" do
      before { stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => "production")) }

      it "returns RAILS_ENV" do
        expect(described_class.environment).to eq("production")
      end
    end

    context "when only RACK_ENV is set" do
      before { stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => nil, "RACK_ENV" => "staging")) }

      it "returns RACK_ENV" do
        expect(described_class.environment).to eq("staging")
      end
    end

    context "when only APP_ENV is set" do
      before do
        stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => nil, "RACK_ENV" => nil, "APP_ENV" => "test"))
      end

      it "returns APP_ENV" do
        expect(described_class.environment).to eq("test")
      end
    end

    context "when no environment variable is set" do
      before { stub_const("ENV", ENV.to_h.merge("RAILS_ENV" => nil, "RACK_ENV" => nil, "APP_ENV" => nil)) }

      it "returns 'unknown'" do
        expect(described_class.environment).to eq("unknown")
      end
    end
  end

  describe ".reset_cache!" do
    it "clears the memoized IP values" do
      stub_request(:get, "https://api.ipify.org").to_return(body: "1.2.3.4")
      stub_request(:get, "https://api64.ipify.org").to_return(body: "::1")

      described_class.public_ipv4
      described_class.public_ipv6
      described_class.reset_cache!

      stub_request(:get, "https://api.ipify.org").to_return(body: "5.6.7.8")
      stub_request(:get, "https://api64.ipify.org").to_return(body: "::2")

      expect(described_class.public_ipv4).to eq("5.6.7.8")
      expect(described_class.public_ipv6).to eq("::2")
    end
  end
end
