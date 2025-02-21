# frozen_string_literal: true

# TODO: Open question: do we need to support run!? should that raise even if it's a user-facing error?

module ServiceAction
  module SwallowExceptions
    GENERIC_ERROR_MESSAGE = "Something went wrong"

    def self.included(base)
      base.class_eval do
        private

        def fail!(message)
          # TODO: implement this centrally
          context.fail!(error: message)
        end

        def run_with_exception_swallowing!
          original_run!
        rescue Interactor::Failure => e
          # NOTE: pretty sure we just want to re-raise these (so we don't hit the unexpected-error case below)
          raise e
        rescue StandardError => e
          # Add custom hook for intercepting exceptions (e.g. Teamshares automatically logs to Honeybadger)
          if self.class.respond_to?(:on_exception)
            begin
              self.class.on_exception(e, context: @context.to_h)
            rescue StandardError
              # No action needed (on_exception should log any internal failures), but we don't want
              # exception *handling* failures to cascade and overwrite the original exception.
            end
          end

          @context.exception = e

          msg = self.class.respond_to?(:generic_error_message) ? self.class.generic_error_message : GENERIC_ERROR_MESSAGE
          fail!(msg)
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!
      end
    end
  end
end
