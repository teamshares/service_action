# frozen_string_literal: true

module Action
  module SwallowExceptions
    def self.included(base)
      base.class_eval do
        class_attribute :_primary_success_msg, :_primary_error_msg, :fail_prefix
        class_attribute :_default_success_msg, default: "Action completed successfully"
        class_attribute :_default_error_msg, default: "Something went wrong"

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

          fail!
        end

        alias_method :original_run!, :run!
        alias_method :run!, :run_with_exception_swallowing!

        # Tweaked to check @context.object_id rather than context (since forwarding object_id causes Ruby to complain)
        # TODO: do we actually need the object_id check? Do we need this override at all?
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
            result = call(context)
            return result if result.ok?

            raise result.exception if result.exception

            raise Action::Failure.new(result.instance_variable_get("@context"), message: result.error)
          end

          alias_method :original_call!, :call!
          alias_method :call!, :call_bang_with_unswallowed_exceptions
        end
      end
    end

    module ClassMethods
      def messages(success: nil, default_success: nil, error: nil, default_error: nil, fail_prefix: nil)
        self._primary_success_msg = success if success.present?
        self._default_success_msg = default_success if default_success.present?
        self._primary_error_msg = error if error.present?
        self._default_error_msg = default_error if default_error.present?
        self.fail_prefix = fail_prefix if fail_prefix.present?

        true
      end
    end

    module InstanceMethods
      private

      def fail!(message = nil)
        @context.instance_variable_set("@failure", true)

        @context.error_from_user = message if message.present?
        @context.error_prefix = fail_prefix if fail_prefix.present? && message.present?

        # TODO: should we use context_for_logging here? But doublecheck the one place where we're checking object_id on it...
        raise Action::Failure.new(@context) # rubocop:disable Style/RaiseArgs
      end

      def try
        yield
      rescue Action::Failure => e
        # NOTE: re-raising so we can still fail! from inside the block
        raise e
      rescue StandardError => e
        trigger_on_exception(e)
      end
    end
  end
end
