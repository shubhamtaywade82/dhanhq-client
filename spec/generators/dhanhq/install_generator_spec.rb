# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stringio"
require_relative "../../../lib/generators/dhanhq/install/install_generator"

RSpec.describe Dhanhq::InstallGenerator do
  let(:destination_root) { Dir.mktmpdir("dhanhq_install_generator_spec") }

  after { FileUtils.remove_entry(destination_root) }

  def run_generator
    original_stdout = $stdout
    $stdout = StringIO.new
    described_class.new([], {}, destination_root: destination_root).invoke_all
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  def generated(path)
    File.read(File.join(destination_root, path))
  end

  it "creates the initializer wired to Rails credentials and configure_with_env" do
    run_generator

    content = generated("config/initializers/dhanhq.rb")
    expect(content).to include("Rails.application.credentials.dig(:dhanhq)")
    expect(content).to include("DhanHQ.configure_with_env")
  end

  it "creates an order-placing service using the bang variant with a specific rescue per error class" do
    run_generator

    content = generated("app/services/dhan/orders/place_order.rb")
    expect(content).to include("module Dhan")
    expect(content).to include("class PlaceOrder")
    expect(content).to include("DhanHQ::Models::Order.place!(@params)")
    expect(content).to include("rescue DhanHQ::OrderError")
    expect(content).to include("rescue DhanHQ::RiskViolation")
  end

  it "creates a Sidekiq worker that blocks for the life of the connection" do
    run_generator

    content = generated("app/workers/dhan_market_feed_worker.rb")
    expect(content).to include("include Sidekiq::Worker")
    expect(content).to include("DhanHQ::WS.connect(mode: mode.to_sym)")
    expect(content).to include('ActionCable.server.broadcast("dhan_market_feed", tick)')
  end

  it "creates an ActionCable channel that streams from the same name the worker broadcasts to" do
    run_generator

    worker = generated("app/workers/dhan_market_feed_worker.rb")
    channel = generated("app/channels/dhan_market_feed_channel.rb")

    expect(channel).to include("class DhanMarketFeedChannel < ApplicationCable::Channel")
    expect(channel).to include('stream_from "dhan_market_feed"')
    expect(worker).to include('ActionCable.server.broadcast("dhan_market_feed"')
  end

  it "prints a post-install message pointing at credentials setup and the worker" do
    output = run_generator

    expect(output).to include("rails credentials:edit")
    expect(output).to include("DhanMarketFeedWorker.perform_async")
  end

  it "only references classes and methods that actually exist in this gem" do
    # Order.place! (bang variants) and DhanHQ::RiskViolation are exactly the kind of
    # thing that silently drifts from the real API in hand-written docs/templates --
    # lock them down here instead of trusting the generated source by inspection alone.
    expect(DhanHQ::Models::Order).to respond_to(:place!)
    expect(DhanHQ::OrderError.ancestors).to include(DhanHQ::Error)
    expect(DhanHQ::RiskViolation.ancestors).to include(DhanHQ::Error)
  end
end
