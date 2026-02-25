# frozen_string_literal: true

module DhanHQ
  module Models
    module Concerns
      # Shared behavior for handling API responses and error logging in models.
      module ApiResponseHandler
        private

        # Handles a standard API response, merging attributes on success or logging error on failure.
        #
        # @param response [Hash, Array] The raw API response
        # @param success_key [String, nil] Key to check for specific success identifier (e.g., "orderId")
        # @param context [String] Context for logging (e.g., "[DhanHQ::Models::Order] Placement")
        # @param error_target [Symbol] Where to store errors (defaults to :@errors)
        # @return [Boolean] True if successful
        def handle_api_response(response, success_key: nil, context: nil) # rubocop:disable Naming/PredicateMethod
          response = response.with_indifferent_access if response.respond_to?(:with_indifferent_access)
          is_hash = response.is_a?(Hash)
          is_success = success_response?(response) || (is_hash && success_key && response[success_key])

          if is_success
            @attributes.merge!(normalize_keys(response))
            assign_attributes
            DhanHQ.logger&.info("#{context} successfully: #{identifier_from(response, success_key) || id}") if context
            true
          else
            error_msg = is_hash ? response[:errorMessage] || response[:message] || "Unknown error" : "Invalid response format"
            DhanHQ.logger&.error("#{context} failed: #{error_msg}") if context
            instance_variable_set(error_target_variable, response) if is_hash
            false
          end
        end

        def error_target_variable
          :@errors
        end

        # Safely fetches an ID or response identifier
        def identifier_from(response, key)
          response.is_a?(Hash) ? response[key] : nil
        end
      end
    end
  end
end
