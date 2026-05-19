# frozen_string_literal: true

RSpec.describe DhanHQ::WS::SingletonLock do
  let(:lock) { described_class.new(token: "token", client_id: "client") }

  after do
    lock.release!
  rescue StandardError
    nil
  end

  it "acquires and releases the lock" do
    expect(lock.acquire!).to be(true)
    expect { lock.release! }.not_to raise_error
  end
end
