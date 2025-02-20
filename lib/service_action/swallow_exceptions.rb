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
          # TODO: do we want to reraise this here?
          puts "SwallowExceptions caught #{e.class.name} (reraising): #{e}"
          raise e
        rescue StandardError => e
          puts "SwallowExceptions caught #{e.class.inspect} (converting into Interactor failure): #{e.message}"

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

          fail!(GENERIC_ERROR_MESSAGE)
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!
      end
    end
  end
end
