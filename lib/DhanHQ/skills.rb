# frozen_string_literal: true

module DhanHQ
  # Multi-step trading workflows built on top of MCP tools.
  #
  # Skills compose individual tool calls into reusable trading strategies.
  # Each skill defines a sequence of steps that execute in order, with
  # context passed between steps.
  #
  # @example Define a custom skill
  #   class MySkill < DhanHQ::Skills::Base
  #     param :symbol, type: :string, required: true
  #     param :quantity, type: :integer, default: 1
  #
  #     step :find_instrument
  #     step :place_order
  #
  #     def find_instrument(ctx)
  #       ctx[:instrument] = DhanHQ::Models::Instrument.find("NSE_EQ", ctx[:symbol])
  #     end
  #
  #     def place_order(ctx)
  #       DhanHQ::Models::Order.place(security_id: ctx[:instrument].security_id, quantity: ctx[:quantity])
  #     end
  #   end
  #
  module Skills
  end
end
