# frozen_string_literal: true

module ServiceAction
  module MetricsHook
    def self.included(base)
      base.class_eval do
        # This class defines a hook implementing classes can use to wrap their actions in a metrics block.
        # (We have to bother with the hook to let the implementing class's around hook get run outside the other hooks)

        around :metrics_hook

        include InstanceMethods
      end
    end

    # TODO: clean this up (just trying to avoid error if downstream doesn't define metrics_hook)
    module InstanceMethods
      # TODO: if we resolve load order issues we shouldn't need a separate hook at all
      def metrics_hook(interactor)
        super
      rescue NoMethodError
        # No metrics hook defined by implementation class
        interactor.call
        # No metrics hook defined -- would log here if we know how to get to a logger in non-Rails context
      end
    end
  end
end
