# frozen_string_literal: true

module ServiceAction
  module MetricsHook
    def self.included(base)
      base.class_eval do
        # This class defines a hook implementing classes can use to wrap their actions in a metrics block.
        # (We have to bother with the hook to let the implementing class's around hook get run outside the other hooks)
        return unless base.respond_to?(:metrics_hook)

        around do |hooked|
          base.metrics_hook(hooked)
        end
      end
    end
  end
end
