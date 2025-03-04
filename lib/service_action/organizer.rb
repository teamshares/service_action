# frozen_string_literal: true

module ServiceAction
  # NOTE: replaces, rather than layers on, the upstream Interactor::Organizer module (only three methods, and
  # we want ability to implement a more complex interface where we pass options into the organized interactors)
  module Organizer
    def self.included(base)
      base.class_eval do
        include ::ServiceAction

        extend ClassMethods
        include InstanceMethods
      end
    end

    # NOTE: pulled unchanged from https://github.com/collectiveidea/interactor/blob/master/lib/interactor/organizer.rb
    module ClassMethods
      def organize(*interactors)
        @organized = interactors.flatten
      end

      def organized
        @organized ||= []
      end
    end

    module InstanceMethods
      def call
        self.class.organized.each do |step|
          (interactor, config) = if step.is_a?(Hash)
                                   [step.delete(:action), step]
                                 else
                                   [step, {}]
                                 end

          # TODO: raise if this is missing
          # next unless interactor

          if should_skip_step?(config)
            # TODO: better logging for proc/anonymous class
            debug("Skipping step #{interactor} due to configuration")
          else
            interactor = convert_to_action(interactor)

            wrapper = config[:critical] === false ? :noncritical_step : :depends_on

            send(wrapper) { interactor.call(@context) }
          end
        end
      end

      private

      def noncritical_step(&block)
        result = noncritical(&block)
        return result if result.ok?

        result.send(:reset_failure!)
      end

      def should_skip_step?(config)
        # TODO: support unless as well
        return false unless config.key?(:if)

        checker = case config[:if]
                  in Symbol then -> { send(config[:if]) }
                  in Proc then config[:if]
                  else -> { true }
                  end

        begin
          !checker.call
        rescue StandardError => e
          # TODO: check if this branch gets called as expected
          log("Error evaluating if condition: #{e}")
          true
        end
      end

      def convert_to_action(given)
        return unless given

        return convert_proc_to_action(given) if given.is_a?(Proc)

        return given if given < ServiceAction

        # TODO: never called?
        raise ArgumentError, "Expected an interactor, got #{given}"
      end

      def convert_proc_to_action(given)
        # TODO: handle `keyrest` -- unsupported
        # TODO: handle any others -- unknown and unsupported
        expected = given.parameters.select { |(type, _)| %i[key keyreq].include?(type) }.map(&:last)

        Class.new do
          include ServiceAction

          expects(*expected)

          define_method(:call) do
            kwargs = expected.each_with_object({}) do |name, hash|
              hash[name] = inbound_context.send(name)
            end

            given.call(**kwargs)
          end
        end
      end
    end
  end
end
