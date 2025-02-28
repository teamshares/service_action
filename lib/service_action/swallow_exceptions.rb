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
    def self.included(base)
      base.class_eval do
        include InstanceMethods
        extend ClassMethods

        def run_with_exception_swallowing!
          original_run!
        rescue Interactor::Failure => e
          # Just re-raise these (so we don't hit the unexpected-error case below)
          raise e
        rescue StandardError => e
          # Add custom hook for intercepting exceptions (e.g. Teamshares automatically logs to Honeybadger)
          trigger_on_exception(e)

          @context.exception = e

          fail_with(self.class.determine_error_message_for(e))
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!

        # Tweaked to check @context.object_id rather than context (since forwarding object_id causes Ruby to complain)
        def run
          run!
        rescue Interactor::Failure => e
          raise if @context.object_id != e.context.object_id
        end

        def trigger_on_exception(e)
          return unless self.class.respond_to?(:on_exception)

          self.class.on_exception(e, context: respond_to?(:context_for_logging) ? context_for_logging : @context.to_h)
        rescue StandardError => e
          # No action needed -- downstream #on_exception implementation should ideally log any internal failures, but
          # we don't want exception *handling* failures to cascade and overwrite the original exception.
          log("#{e.class.name} in on_exception hook: #{e.message}", :warn)
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
      end
    end

    module ClassMethods
      def error_for(*args, **kwargs)
        if args.any?
          if args.size != 2
            raise ArgumentError,
                  "error_for must be called with either two positional arguments or a hash of key/value pairs"
          end

          kwargs.merge!(args.first => args.last)
        end

        unless kwargs.keys.all? do |k|
          k.is_a?(Class) || k.is_a?(String) || k.is_a?(Symbol)
        end
          raise ArgumentError,
                "error_for keys must be exception class names (or the classes themselves)"
        end

        unless kwargs.values.all? do |k|
          k.is_a?(String) || k.respond_to?(:call)
        end
          raise ArgumentError,
                "error_for values must be strings (the message to return) or callable"
        end

        @message_by_exception_klass = (@message_by_exception_klass || {}).merge(kwargs.stringify_keys)
      end

      GENERIC_ERROR_MESSAGE = "Something went wrong"

      def determine_error_message_for(exception)
        custom = (@message_by_exception_klass || {})[exception.class.to_s]

        if custom.respond_to?(:call)
          begin
            return custom.call(exception)
          rescue StandardError
            nil
          end
        elsif custom.present?
          return custom
        end

        generic_error_message
      end

      def generic_error_message = GENERIC_ERROR_MESSAGE
    end

    module InstanceMethods
      private

      def fail_with(message)
        # TODO: implement this centrally
        @context.fail!(error: message)
      end

      def noncritical
        yield
      rescue Interactor::Failure => e
        # NOTE: reraising so we can still fail_with from inside the block
        raise e
      rescue StandardError => e
        trigger_on_exception(e)
      end
    end
  end
end
