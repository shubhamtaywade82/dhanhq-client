# frozen_string_literal: true

require_relative "ai/context_builder"
require_relative "ai/prompt_helpers"

module DhanHQ
  # AI integration layer for building AI-powered trading assistants.
  #
  # Provides workflow orchestration, prompt helpers, and context
  # serialization for AI agents.
  #
  # @example Build context for AI
  #   context = DhanHQ::AI::ContextBuilder.build do |ctx|
  #     ctx.add_portfolio
  #     ctx.add_positions
  #     ctx.add_recent_orders(limit: 10)
  #   end
  #   puts context.to_prompt
  #
  # @example Generate system prompt
  #   prompt = DhanHQ::AI::PromptHelpers.system_prompt(
  #     capabilities: ["Option chain analysis", "Greeks calculation"]
  #   )
  #
  module AI
  end
end
