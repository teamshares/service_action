# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module Action
  module Logging
    LEVELS = %i[debug info warn error fatal].freeze

    def self.included(base)
      base.class_eval do
        extend ClassMethods
        delegate :log, *LEVELS, to: :class
      end
    end

    module ClassMethods
      def log(message, level: :info)
        level = :info if level == :debug && targeted_for_debug_logging?
        msg = %([#{name || "Anonymous Class"}] #{message})

        logger.send(level, msg)
      end

      LEVELS.each do |level|
        define_method(level) do |message|
          log(message, level: level)
        end
      end

      def targeted_for_debug_logging?
        return true if Action.config.global_debug_logging?

        target_class_names = (ENV["SA_DEBUG_TARGETS"] || "").split(",").map(&:strip)
        target_class_names.include?(name)
      end

      # Hook for implementing classes to override logger
      def logger
        @logger ||= begin
          Rails.logger
        rescue NameError
          Logger.new($stdout).tap do |l|
            l.level = Logger::INFO
          end
        end
      end
    end
  end
end
