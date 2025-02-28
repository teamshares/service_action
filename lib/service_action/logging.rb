# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module ServiceAction
  module Logging
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        include InstanceMethods
      end
    end

    module ClassMethods
      def log(message, level: :info)
        msg = %([#{name || "Anonymous Class"}] #{message})

        logger.send(level, msg)
      end

      # Hook for implementing classes to override logger
      def logger
        @logger ||= begin
          Rails.logger
        rescue NameError
          Logger.new($stdout)
        end
      end
    end

    module InstanceMethods
      delegate :log, to: :class
    end
  end
end
