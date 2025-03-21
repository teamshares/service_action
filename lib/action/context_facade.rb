# frozen_string_literal: true

require "active_support/parameter_filter"

module Action
  class ContextFacade
    def initialize(action:, context:, declared_fields:, implicitly_allowed_fields: nil)
      if self.class.name == "Action::ContextFacade" # rubocop:disable Style/ClassEqualityComparison
        raise "Action::ContextFacade is an abstract class and should not be instantiated directly"
      end

      @context = context
      @action = action
      @declared_fields = declared_fields

      (@declared_fields + Array(implicitly_allowed_fields)).each do |field|
        singleton_class.define_method(field) { @context.public_send(field) }
      end
    end

    attr_reader :declared_fields

    def inspect = Inspector.new(facade: self, action:, context:).call

    def fail!(...)
      raise Action::ContractViolation::MethodNotAllowed, "Call fail! directly rather than on the context"
    end

    private

    attr_reader :action, :context

    def exposure_method_name = raise NotImplementedError

    # Add nice error message for missing methods
    def method_missing(method_name, ...) # rubocop:disable Style/MissingRespondToMissing (because we're not actually responding to anything additional)
      if context.respond_to?(method_name)
        msg = <<~MSG
          Method ##{method_name} is not available on #{self.class.name}!

          #{@action.class.name || "The action"} may be missing a line like:
            #{exposure_method_name} :#{method_name}
        MSG

        raise Action::ContractViolation::MethodNotAllowed, msg
      end

      super
    end
  end

  # Inbound / Internal ContextFacade
  class InternalContext < ContextFacade
    private

    def exposure_method_name = :expects
  end

  # Outbound / External ContextFacade
  class Result < ContextFacade
    # Poke some holes for necessary internal control methods
    delegate :called!, :rollback!, :each_pair, to: :context

    # External interface
    delegate :success?, :failure?, :exception, to: :context
    def ok? = success?

    def error
      return if ok?

      msg = @context.error_from_user.presence || determine_message(
        primary: action._primary_error_msg,
        default: action._default_error_msg,
        exception:,
      ) || "Something went wrong"

      [@context.error_prefix, msg].compact.join(" ").squeeze(" ")
    end

    def success
      return unless ok?

      determine_message(
        primary: action._primary_success_msg,
        default: action._default_success_msg,
      ) || "Action completed successfully"
    end

    def ok = success

    def message = error || success

    private

    def exposure_method_name = :exposes

    def determine_message(primary:, default:, exception: nil)
      stringified(primary, exception:).presence || stringified(default, exception:).presence
    end

    # Allow for callable OR string messages
    def stringified(msg, exception: nil)
      return msg.presence unless msg.respond_to?(:call)

      # The error message callable can take the exception as an argument
      if exception && msg.arity == 1
        action.instance_exec(exception, &msg)
      else
        action.instance_exec(&msg)
      end
    rescue StandardError => e
      action.warn("Ignoring #{e.class.name} raised while determining message callable: #{e.message}")
      nil
    end
  end

  class Inspector
    def initialize(action:, facade:, context:)
      @action = action
      @facade = facade
      @context = context
    end

    def call
      str = [status, visible_fields].compact_blank.join(" ")

      "#<#{class_name} #{str}>"
    end

    private

    attr_reader :action, :facade, :context

    def status
      return unless facade.is_a?(Action::Result)

      return "[OK]" if context.success?
      return "[failed with '#{context.error_from_user}']" unless context.exception

      %([failed with #{context.exception.class.name}: '#{context.exception.message}'])
    end

    def visible_fields
      declared_fields.map do |field|
        value = facade.public_send(field)

        "#{field}: #{format_for_inspect(field, value)}"
      end.join(", ")
    end

    def class_name = facade.class.name
    def declared_fields = facade.send(:declared_fields)

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

    def inspection_filter = action.send(:inspection_filter)
  end
end
