# frozen_string_literal: true

module Action
  module SwallowExceptions
    def self.included(base)
      base.class_eval do
        class_attribute :custom_success, :custom_error, :fail_prefix
        class_attribute :default_success, default: "Action completed successfully"
        class_attribute :default_error, default: "Something went wrong"

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

          fail! self.class.determine_error_message_for(e), __skip_message_processing: true
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!

        # Tweaked to check @context.object_id rather than context (since forwarding object_id causes Ruby to complain)
        # TODO: do we actually need the object_id check?
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
          warn("Ignoring #{e.class.name} in on_exception hook: #{e.message}")
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
      def messages(success: nil, default_success: nil, error: nil, default_error: nil, fail_prefix: nil)
        self.custom_success = success if success.present?
        self.default_success = default_success if default_success.present?
        self.custom_error = error if error.present?
        self.default_error = default_error if default_error.present?
        self.fail_prefix = fail_prefix if fail_prefix.present?

        true
      end

      def determine_error_message_for(exception)
        msg = custom_error

        if msg.respond_to?(:call)
          msg = begin
            if msg.arity == 1
              instance_exec(exception, &msg)
            else
              instance_exec(&msg)
            end
          rescue StandardError => e
            warn("Ignoring #{e.class.name} in error message callable: #{e.message}")
            nil
          end
        end

        msg.presence || default_error
      end
    end

    module InstanceMethods
      private

      # NOTE: when user facing, __skip_message_processing should be false so we apply the fail_prefix
      # if set. When used internally, it should be true so we don't double-prefix the message.
      def fail!(message, __skip_message_processing: false) # rubocop:disable Lint/UnderscorePrefixedVariableName
        message = [fail_prefix, message].compact.join(" ").squish unless __skip_message_processing

        @context.error = message
        @context.instance_variable_set("@failure", true)

        # TODO: should we use context_for_logging here? But doublecheck the one place where we're checking object_id on it...
        raise Action::Failure.new(message, @context)
      end

      def try
        yield
      rescue Action::Failure => e
        # NOTE: reraising so we can still fail! from inside the block
        raise e
      rescue StandardError => e
        trigger_on_exception(e)
      end
    end
  end
end
