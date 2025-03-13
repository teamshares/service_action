# frozen_string_literal: true

module Action
  class Configuration
    attr_accessor :global_debug_logging, :on_exception, :top_level_around_hook, :additional_includes

    def global_debug_logging? = global_debug_logging

    def on_exception(e, context: {}) = @on_exception&.call(e, context:) # rubocop:disable Lint/DuplicateMethods
  end

  class << self
    def config = @config ||= Configuration.new

    def configure
      self.config ||= Configuration.new
      yield(config) if block_given?
    end
  end
end
