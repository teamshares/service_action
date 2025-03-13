# frozen_string_literal: true

module Action
  # Raised internally when fail_with is called -- triggers failure + rollback handling
  class Failure < StandardError
    attr_reader :context

    def initialize(message, context = nil)
      super(message)
      @context = context
    end

    def message = super.presence || "Execution was intentionally stopped"
  end

  class ContractViolation < StandardError
    class MethodNotAllowed < ContractViolation; end
    class PreprocessingError < ContractViolation; end

    class InvalidExposure < ContractViolation
      def initialize(key)
        @key = key
        super()
      end

      def message = "Attempted to expose unknown key '#{@key}': be sure to declare it with `exposes :#{@key}`"
    end

    class ValidationError < ContractViolation
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super
      end

      def message = errors.full_messages.to_sentence
      def to_s = message
    end

    class InboundValidationError < ValidationError; end
    class OutboundValidationError < ValidationError; end
  end
end
