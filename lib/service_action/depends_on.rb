# frozen_string_literal: true

module ServiceAction
  module DependsOn
    def self.included(base)
      base.class_eval do
        include InstanceMethods
      end
    end

    module InstanceMethods
      private

      # TODO: extract to own layer (and - maybe don't take direct call, decompose instead?)
      # TODO: downstream uses the wrapped version, and I think we want that to set thread-local variables anyway
      def depends_on(error_prefix: nil)
        raise ArgumentError, "must provide a block to execute" unless block_given?

        result = yield @context
        # TODO: ensure this has spec coverage
        raise "#depends_on block must return a service call (expected to implement ok?)" unless result.respond_to?(:ok?)
        return if result.ok?

        handle_depended_upon_output(result, error_prefix:)
      end

      def handle_depended_upon_output(result, error_prefix: nil)
        fail_with([error_prefix, result.error].compact.join(": "))
      end
    end
  end
end
