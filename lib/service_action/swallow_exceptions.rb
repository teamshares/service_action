# frozen_string_literal: true

module Interactor
  class Failure < StandardError
    def message
      context.error || "Execution was intentionally stopped"
    end
  end
end

module ServiceAction
  module SwallowExceptions
    GENERIC_ERROR_MESSAGE = "Something went wrong"

    def self.included(base)
      base.class_eval do
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
          fail_with(msg)
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!

        # Tweaked to check @context.object_id rather than context (since forwarding object_id causes Ruby to complain)
        def run
          run!
        rescue Interactor::Failure => e
          if @context.object_id != e.context.object_id
            raise
          end
        end

        class << base
          def call_bang_with_unswallowed_exceptions(context = {})
            original_call!(context)
          rescue Interactor::Failure => e
            # De-swallow the exception, if we caught any failures
            raise e.context.exception if e.context.exception

            # Otherwise just raise the Interactor::Failure
            raise
          end

          alias_method :original_call!, :call!
          alias_method :call!, :call_bang_with_unswallowed_exceptions
        end

        private

        def fail_with(message)
          # TODO: implement this centrally
          @context.fail!(error: message)
        end
      end
    end
  end
end
