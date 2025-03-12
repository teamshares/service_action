# frozen_string_literal: true

module ServiceAction; end
require_relative "service_action/version"

require "interactor"

require "active_support"

require_relative "action/configuration"
require_relative "action/exceptions"
require_relative "action/metrics_hook"
require_relative "action/logging"
require_relative "action/restrict_context_access"
require_relative "action/swallow_exceptions"
require_relative "action/depends_on"

require_relative "action/organizer"
require_relative "action/enqueueable"

module Action
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

      include DependsOn

      include Enqueueable

      # Allow additional automatic includes to be configured
      Array(Action.config.additional_includes).each { |mod| include mod }
    end
  end
end
