# frozen_string_literal: true

module DhanHQ
  module Agent
    # Recursive key coercion for arguments crossing the agent boundary.
    #
    # MCP delivers arguments as JSON, so keys arrive as strings; handlers and the risk
    # pipeline expect symbols and strings respectively.
    #
    # Called explicitly (`KeyCoercion.symbolize(...)`) rather than mixed in, so there is
    # no question about method visibility at the call site.
    module KeyCoercion
      module_function

      # @param value [Hash, Array, Object]
      # @return [Hash, Array, Object] Same shape with symbol keys throughout.
      def symbolize(value)
        case value
        when Hash then value.each_with_object({}) { |(key, val), hash| hash[key.to_sym] = symbolize(val) }
        when Array then value.map { |val| symbolize(val) }
        else value
        end
      end

      # @param value [Hash, Array, Object]
      # @return [Hash, Array, Object] Same shape with string keys throughout.
      def stringify(value)
        case value
        when Hash then value.each_with_object({}) { |(key, val), hash| hash[key.to_s] = stringify(val) }
        when Array then value.map { |val| stringify(val) }
        else value
        end
      end
    end
  end
end
