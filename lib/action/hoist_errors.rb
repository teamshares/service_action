# frozen_string_literal: true

module Action
  module HoistErrors
    def self.included(base)
      base.class_eval do
        include InstanceMethods
      end
    end

    module InstanceMethods
      private

      MinimalFailedResult = Data.define(:error) do
        def ok? = false
      end

      # This method is used to ensure that the result of a block is successful before proceeding.
      #
      # Assumes success unless the block raises an exception or returns a failed result.
      # (i.e. if you wrap logic that is NOT an action call, it'll be successful unless it raises an exception)
      def hoist_errors(prefix: nil)
        raise ArgumentError, "#hoist_errors must be given a block to execute" unless block_given?

        result = begin
          yield
        rescue StandardError => e
          warn "hoist_errors block swallowed an exception: #{e.message}"
          @context.exception = e
          MinimalFailedResult.new(error: self.class.determine_error_message_for(e))
        end

        # This ensures the last line of hoist_errors was an Action call (CAUTION: if there are multiple
        # calls per block, only the last one will be checked!)
        unless result.respond_to?(:ok?)
          raise ArgumentError,
                "#hoist_errors is expected to wrap an Action call, but it returned a #{result.class.name} instead"
        end

        handle_hoisted_errors(result, prefix:) unless result.ok?
      end

      # Separate method to allow overriding in subclasses
      def handle_hoisted_errors(result, prefix: nil)
        fail! [prefix, result.error].compact.join(": "), __skip_message_processing: true
      end
    end
  end
end
