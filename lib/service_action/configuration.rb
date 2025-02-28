# frozen_string_literal: true

module ServiceAction
  class Configuration
    attr_accessor :global_debug_logging

    def global_debug_logging? = global_debug_logging
  end

  class << self
    def config = @config ||= Configuration.new

    def configure
      self.config ||= Configuration.new
      yield(config) if block_given?
    end
  end
end
