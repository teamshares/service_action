# frozen_string_literal: true

module Action
  module SwallowExceptions
    def self.included(base)
      base.class_eval do
        include InstanceMethods
        extend ClassMethods

        def run_with_exception_swallowing!
          original_run!
        rescue Action::Failure => e
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
        rescue Action::Failure => e
          raise if @context.object_id != e.context.object_id
        end

        def trigger_on_exception(e)
          Action.config.on_exception(e,
                                     context: respond_to?(:context_for_logging) ? context_for_logging : @context.to_h)
        rescue StandardError => e
          # No action needed -- downstream #on_exception implementation should ideally log any internal failures, but
          # we don't want exception *handling* failures to cascade and overwrite the original exception.
          log("Ignoring #{e.class.name} in on_exception hook: #{e.message}", :warn)
        end

        class << base
          def call_bang_with_unswallowed_exceptions(context = {})
            original_call!(context)
          rescue Action::Failure => e
            # De-swallow the exception, if we caught any
            raise e.context.exception if e.context.exception

            # Otherwise just raise the Failure
            raise
          end

          alias_method :original_call!, :call!
          alias_method :call!, :call_bang_with_unswallowed_exceptions
        end
      end
    end

    module ClassMethods
      def success_message(message)
        # NOTE: maybe in the future we'll want more complexity here, but for now just a string
        raise ArgumentError, "success_message must be called with a string" unless message.is_a?(String)

        @success_message = message
      end

      def error_message(*args, **kwargs)
        case args.size
        when 0 # no action needed
        when 1 then kwargs.merge!(default: args.last)
        when 2 then kwargs.merge!(args.first => args.last)
        else
          raise ArgumentError,
                "error_message must be called with either two positional arguments or a hash of key/value pairs"
        end

        unless kwargs.keys.all? do |k|
          k.is_a?(Class) || k.is_a?(String) || k.is_a?(Symbol)
        end
          raise ArgumentError,
                "error_message keys must be exception class names (or the classes themselves)"
        end

        unless kwargs.values.all? do |k|
          k.is_a?(String) || k.respond_to?(:call)
        end
          raise ArgumentError,
                "error_message values must be strings (the message to return) or callable"
        end

        @message_by_exception_klass = (@message_by_exception_klass || {}).merge(kwargs.stringify_keys)
      end

      GENERIC_ERROR_MESSAGE = "Something went wrong"

      def generic_error_message
        @message_by_exception_klass ||= {}
        @message_by_exception_klass["default"] || GENERIC_ERROR_MESSAGE
      end

      def determine_error_message_for(exception)
        @message_by_exception_klass ||= {}

        # TODO: is exact string match correct, or should we be using #ancestors.include?
        custom = @message_by_exception_klass[exception.class.to_s] || @message_by_exception_klass["default"]

        if custom.respond_to?(:call)
          begin
            return custom.call(exception)
          rescue StandardError => e
            log("Ignoring #{e.class.name} in error_message callable: #{e.message}", :warn)
          end
        elsif custom.present?
          return custom
        end

        GENERIC_ERROR_MESSAGE
      end
    end

    module InstanceMethods
      private

      def fail_with(message)
        # TODO: implement this centrally
        @context.error = message
        @context.instance_variable_set("@failure", true)

        # TODO: should we use context_for_logging here? But doublecheck the one place where we're checking object_id on it...
        raise Action::Failure.new(message, @context)
      end

      def noncritical
        yield
      rescue Action::Failure => e
        # NOTE: reraising so we can still fail_with from inside the block
        raise e
      rescue StandardError => e
        trigger_on_exception(e)
      end
    end
  end
end
