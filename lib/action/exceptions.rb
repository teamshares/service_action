# frozen_string_literal: true

module Action
  # Raised internally when fail! is called -- triggers failure + rollback handling
  class Failure < StandardError
    attr_reader :context

    def initialize(message, context = nil)
      super(message)
      @context = context
    end

    def message = super.presence || "Execution was intentionally stopped"
  end

  class StepsRequiredForInheritanceSupportError < StandardError
    def message
      <<~MSG
        ** Inheritance support requires the following steps: **

        Add this to your Gemfile:
          gem "interactor", github: "kaspermeyer/interactor", branch: "fix-hook-inheritance"

        Explanation:
          Unfortunately the upstream interactor gem does not support inheritance of hooks, which is required for this feature.
          This branch is a temporary fork that adds support for inheritance of hooks, but published gems cannot specify a branch dependency.
          In the future we may inline the upstream Interactor gem entirely and remove this necessity, but while we're in alpha we're continuing
          to use the upstream gem for stability (and there has been recent activity on the project, so they *may* be adding additional functionality
          soon).
      MSG
    end
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
  end

  class DuplicateFieldError < ContractViolation; end

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
