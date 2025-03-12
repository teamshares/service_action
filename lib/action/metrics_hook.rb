# frozen_string_literal: true

module Action
  module MetricsHook
    def self.included(base)
      base.class_eval do
        around :metrics_hook

        include InstanceMethods
      end
    end

    module InstanceMethods
      def metrics_hook(hooked)
        timing_start = Time.now
        _log_before

        _metrics_wrapper do
          (@outcome, @exception) = _call_and_return_outcome(hooked)
        end

        _log_after(timing_start:, outcome: @outcome)

        raise @exception if @exception
      end

      private

      def _metrics_wrapper(&)
        return yield unless Action.config.metrics_hook

        Action.config.metrics_hook.call(self.class.name || "AnonymousClass", &)
      end

      def _log_before
        debug [
          "About to execute",
          context_for_logging(:inbound).presence&.inspect
        ].compact.join(" with: ")
      end

      def _log_after(outcome:, timing_start:)
        elapsed_mils = (Time.now - timing_start) * 1000

        debug [
          "Execution completed (with outcome: #{outcome}) in #{elapsed_mils} milliseconds",
          context_for_logging(:outbound).presence&.inspect
        ].compact.join(". Set: ")
      end

      def _call_and_return_outcome(hooked)
        hooked.call

        "success"
      rescue StandardError => e
        [
          e.is_a?(Action::Failure) ? "expected_failure" : "exception",
          e
        ]
      end
    end
  end
end
