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

  class ContextFacade
    class MethodNotAllowed < NoMethodError; end
  end

  module Contract
    class Violation < StandardError
      class PreprocessingError < Violation; end

      class InvalidExposure < Violation
        def initialize(key)
          @key = key
          super()
        end

        def message = "Attempted to expose unknown key '#{@key}': be sure to declare it with `exposes :#{@key}`"
      end

      class ValidationBase < Violation
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super
        end

        def message
          errors.full_messages.to_sentence
        end
      end

      class InboundValidation < ValidationBase; end
      class OutboundValidation < ValidationBase; end
    end
  end
end
