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
      # TODO: extract to own layer (and - maybe don't take direct call, decompose instead?)
      def depends_on(interactor, error_prefix: nil)
        result = interactor.call(@context)
        return if result.success?

        fail_with([error_prefix, result.error].compact.join(" "))
      end

      # NOTE: override to use the `depends_on` method (internally, replaces call! with call + overrides to use @context directly)
      def call
        self.class.organized.each do |interactor|
          depends_on interactor
        end
      end
    end
  end
end
