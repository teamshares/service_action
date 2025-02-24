# frozen_string_literal: true

require_relative "service_action/version"

require "interactor"

require_relative "service_action/metrics_hook"
require_relative "service_action/contractual_context_interface"
require_relative "service_action/swallow_exceptions"

require_relative "service_action/organizer"

module ServiceAction
  def self.included(base)
    base.class_eval do
      include Interactor

      # NOTE: first include, so we start the trace before we do anything else (like contract validation)
      include MetricsHook

      include ContractualContextInterface
      include SwallowExceptions
    end
  end
end
