# frozen_string_literal: true

require "active_support/parameter_filter"

module Action
  class ContextFacade
    def initialize(interactor, direction, context)
      @context = context
      @direction = direction
      @interactor = interactor

      @allowed_fields = @interactor.class.instance_variable_get("@#{direction}_accessors").compact

      @allowed_fields.each do |field|
        singleton_class.define_method(field) { @context.public_send(field) }
      end
    end

    attr_reader :allowed_fields

    def inspect = Inspector.new(facade: self, interactor:, context:, direction:).call

    delegate :success?, :failure?, :error, :exception, to: :context
    def ok? = success?

    def success
      return unless success?

      interactor.class.instance_variable_get("@success_message").presence || GENERIC_SUCCESS_MESSAGE
    end
    GENERIC_SUCCESS_MESSAGE = "Action completed successfully"

    def message = error || success

    def fail!(...)
      raise Action::ContractViolation::MethodNotAllowed,
            "Cannot fail! directly -- either use fail_with or allow an exception to bubble up uncaught"
    end

    private

    attr_reader :interactor, :direction, :context

    def exposure_method_name = direction == :inbound ? :expects : :exposes

    INTERNALLY_USED_METHODS = %i[called! rollback! each_pair].freeze

    # Add nice error message for missing methods
    def method_missing(method_name, ...)
      if context.respond_to?(method_name)
        # Ideally Interactor base module would use @context rather than the context accessor
        # (since in our version, we want to disallow implementing services to directly access context).
        #
        # To avoid rewriting the methods directly to change to use @context, we redefine #context to
        # return the #outbound_context.  That's great for external access, but in the outbound context case
        # we need to allow the internal control methods to pass through.
        return context.send(method_name, ...) if direction == :outbound && INTERNALLY_USED_METHODS.include?(method_name)

        msg = <<~MSG
          Method ##{method_name} is not available on the #{@direction} context facade!

          #{@interactor.class.name || "The interactor"} is missing a line like:
            #{exposure_method_name} :#{method_name}
        MSG

        raise Action::ContractViolation::MethodNotAllowed, msg
      end

      super
    end

    def respond_to_missing?(method_name, include_private = false)
      return direction == :outbound && INTERNALLY_USED_METHODS.include?(method_name) if context.respond_to?(method_name)

      super
    end
  end

  class Inspector
    def initialize(interactor:, facade:, context:, direction:)
      @interactor = interactor
      @facade = facade
      @context = context
      @direction = direction
    end

    def class_name = "#{direction.to_s.capitalize}ContextFacade"

    def call
      str = [status, visible_fields].compact_blank.join(" ")

      "#<#{direction.to_s.capitalize}ContextFacade #{str}>"
    end

    private

    attr_reader :interactor, :facade, :context, :direction

    def direction_label = direction.to_s.capitalize

    def status
      return unless direction == :outbound
      return "[OK]" if context.success?
      return "[failed with '#{context.error}']" unless context.exception

      %([failed with #{context.exception.class.name}: '#{context.exception.message}'])
    end

    def visible_fields
      allowed_fields.map do |field|
        value = @facade.public_send(field)

        "#{field}: #{format_for_inspect(field, value)}"
      end.join(", ")
    end

    def allowed_fields = @facade.send(:allowed_fields)

    def format_for_inspect(field, value)
      return value.inspect if value.nil?

      # Initially based on https://github.com/rails/rails/blob/800976975253be2912d09a80757ee70a2bb1e984/activerecord/lib/active_record/attribute_methods.rb#L527
      inspected_value = if value.is_a?(String) && value.length > 50
                          "#{value[0, 50]}...".inspect
                        elsif value.is_a?(Date) || value.is_a?(Time)
                          %("#{value.to_fs(:inspect)}")
                        elsif defined?(::ActiveRecord::Relation) && value.instance_of?(::ActiveRecord::Relation)
                          # Avoid hydrating full AR relation (i.e. avoid loading records just to report an error)
                          "#{value.name}::ActiveRecord_Relation"
                        else
                          value.inspect
                        end

      inspection_filter.filter_param(field, inspected_value)
    end

    def inspection_filter = interactor.send(:inspection_filter)
  end
end
