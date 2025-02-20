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

          @context.exception = e

          # TODO: Kali -- implement the ability for custom hook here so we can log to honeybadger
          # on_exception(e) #if respond_to?(:on_exception)
          # puts "Failed, reporting to honeybadger: #{@context.to_h}"

          # TODO: Log to honeybadger
          # Honeybadger.notify("[#{self.class.name}] Failed #{direction} validation: #{errors.full_messages.to_sentence}", context: @context)

          fail!(GENERIC_ERROR_MESSAGE)
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!
      end
    end
  end
end
