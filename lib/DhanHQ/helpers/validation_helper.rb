# frozen_string_literal: true

module DhanHQ
  module ValidationHelper
    # Validate the attributes using the validation contract
    #
    # @param params [Hash] The parameters to validate
    # @param contract_class [Class] The contract class to use for validation
    def validate_params!(params, contract_class)
      contract = contract_class.new
      result = contract.call(params)
      raise DhanHQ::Error, "Validation Error: #{result.errors.to_h}" unless result.success?
    end

    # Validate the attributes using the validation contract
    def validate!
      return unless (contract = validation_contract)

      result = contract.call(@attributes)
      @errors = result.errors.to_h unless result.success?
      raise DhanHQ::Error, "Validation Error: #{@errors}" unless valid?
    end
  end
end
