# frozen_string_literal: true

require_relative "service_action/version"

require "interactor"

require "active_support"

require_relative "service_action/metrics_hook"
require_relative "service_action/logging"
require_relative "service_action/restrict_context_access"
require_relative "service_action/swallow_exceptions"

require_relative "service_action/organizer"
require_relative "service_action/enqueueable"

module ServiceAction
  def self.included(base)
    base.class_eval do
      include Interactor

      # Include first so other modules can assume `log` is available
      include Logging

      # NOTE: include before any others that set hooks (like contract validation), so we
      # can include those hook executions in any traces set from this hook.
      include MetricsHook

      include RestrictContextAccess
      include SwallowExceptions

      include Enqueueable
    end
  end
end
