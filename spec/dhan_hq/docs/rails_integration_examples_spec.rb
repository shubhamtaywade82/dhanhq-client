# frozen_string_literal: true

# Locks down the WebSocket API surface that docs/RAILS_INTEGRATION.md's
# Sidekiq worker examples (§5, §6) call by name. The previous versions of
# those examples called client.wait!, client.subscribe(array), and
# DhanHQ::WS::Client.new(kind: :order_updates) -- none of which exist -- and
# nothing caught the drift until it was checked by hand while building the
# dhanhq:install generator. This is that check, kept as a regression guard.
# rubocop:disable RSpec/DescribeClass -- this spec is a docs regression guard, not a class spec
RSpec.describe "docs/RAILS_INTEGRATION.md Sidekiq examples" do
  describe "market feed worker (§5)" do
    it "DhanHQ::WS.connect exists and returns something with the methods the example calls" do
      expect(DhanHQ::WS).to respond_to(:connect)
      expect(DhanHQ::WS::Client.instance_methods).to include(:on, :subscribe_one, :connected?)
    end

    it "DhanHQ::WS::Client has no blocking wait method -- the example must not call one" do
      expect(DhanHQ::WS::Client.instance_methods).not_to include(:wait, :wait!)
    end
  end

  describe "order updates worker (§6)" do
    it "DhanHQ::WS::Orders.connect exists and returns something with the methods the example calls" do
      expect(DhanHQ::WS::Orders).to respond_to(:connect)
      expect(DhanHQ::WS::Orders::Client.instance_methods).to include(:on, :connected?)
    end

    it "DhanHQ::WS::Orders::Client has no blocking wait method -- the example must not call one" do
      expect(DhanHQ::WS::Orders::Client.instance_methods).not_to include(:wait, :wait!)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
