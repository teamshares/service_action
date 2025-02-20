# frozen_string_literal: true

require_relative "service_action/version"

require "interactor"

require_relative "service_action/contractual_context_interface"
require_relative "service_action/swallow_exceptions"


# Pattern to allow outer wrapper to be added later?
module Metricsz
  def self.included(base)
    base.class_eval do
      around do |hooked|
        # TODO: wrap with Datadog::Tracing...
        puts "METRICS START"
        hooked.call
        puts "METRICS END"
      end
    end
  end
end

module ServiceAction
  def self.included(base)
    base.class_eval do
      include Interactor
      include Metrics if defined?(Metrics)
      include ContractualContextInterface
      include SwallowExceptions
    end

    # base.define_singleton_method(:on_exception) do |*args|
    #   puts "GOT !!!!"
    # end
  end
end
