# frozen_string_literal: true

module ServiceAction
  module Organizer
    def self.included(base)
      base.class_eval do
        include Interactor::Organizer
        include ::ServiceAction

        include InstanceMethods
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
