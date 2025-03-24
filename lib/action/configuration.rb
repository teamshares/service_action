# frozen_string_literal: true

module Action
  class Configuration
    include Action::Logging
    attr_accessor :global_debug_logging, :on_exception, :top_level_around_hook, :additional_includes

    def global_debug_logging? = global_debug_logging

    def on_exception(e, action:, context: {}) # rubocop:disable Lint/DuplicateMethods
      if @on_exception
        # TODO: only pass action: or context: if requested
        @on_exception.call(e, action:, context:)
      else
        log("[#{action.class.name}] Exception swallowed: #{e.class.name} - #{e.message}")
      end
    end
  end

  class << self
    def config = @config ||= Configuration.new

    def configure
      self.config ||= Configuration.new
      yield(config) if block_given?
    end
  end
end
