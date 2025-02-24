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
      # NOTE: only override is passing @context rather than context (which is now a facade)
      def call
        self.class.organized.each do |interactor|
          interactor.call!(@context)
        end
      end
    end
  end
end
