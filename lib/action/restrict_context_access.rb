# frozen_string_literal: true

require "active_model"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"

require "action/contract_validator"

module Action
  module RestrictContextAccess
    def self.included(base)
      base.class_eval do
        @inbound_preprocessing ||= {}
        @inbound_accessors ||= []
        @outbound_accessors ||= []
        @sensitive_fields ||= []
        @inbound_defaults = {}
        @outbound_defaults = {}
        @inbound_validations = Hash.new { |h, k| h[k] = {} }
        @outbound_validations = Hash.new { |h, k| h[k] = {} }

        extend ClassMethods
        include InstanceMethods
        include ValidationInstanceMethods

        # Remove public context accessor
        remove_method :context

        around do |hooked|
          apply_inbound_preprocessing!
          apply_inbound_defaults!
          validate_context!(:inbound)
          hooked.call
          apply_outbound_defaults!
          validate_context!(:outbound)
        end
      end
    end

    module ClassMethods
      def expects(*fields, allow_blank: false, default: nil, preprocess: nil, sensitive: false,
                  **additional_validations)
        fields.map do |field|
          @inbound_accessors << field
          @inbound_preprocessing[field] = preprocess if preprocess.present?
          @sensitive_fields << field if sensitive

          if allow_blank
            additional_validations.transform_values! do |v|
              v = v.is_a?(Hash) ? v : { value: v }
              { allow_blank: true }.merge(v)
            end
          else
            # TODO: do we need to merge allow_blank into all _other_ validations' options?
            @inbound_validations[field][:presence] = !additional_validations.key?(:boolean)
          end

          # TODO: do we need to merge allow_blank into all subsequent validations' options?
          @inbound_validations[field].merge!(additional_validations) if additional_validations.present?

          # Allow local access to explicitly-expected fields
          define_method(field) { inbound_context.public_send(field) }

          @inbound_defaults[field] = default if default.present?

          field
        end
      end

      def exposes(*fields, allow_blank: false, default: nil, sensitive: false, **additional_validations)
        fields.map do |field|
          @outbound_accessors << field
          @sensitive_fields << field if sensitive

          if allow_blank
            additional_validations.transform_values! do |v|
              v = v.is_a?(Hash) ? v : { value: v }
              { allow_blank: true }.merge(v)
            end
          else
            # TODO: do we need to merge allow_blank into all _other_ validations' options?
            @outbound_validations[field][:presence] = !additional_validations.key?(:boolean)
          end

          @outbound_validations[field].merge!(additional_validations) if additional_validations.present?
          @outbound_defaults[field] = default if default.present?

          field
        end
      end
    end

    module InstanceMethods
      def inbound_context = @inbound_context ||= ContextFacade.new(self, :inbound, @context)
      def outbound_context = @outbound_context ||= ContextFacade.new(self, :outbound, @context)

      # NOTE: ideally no direct access from client code, but we need to expose this for internal Interactor methods
      # (and passing through control methods to underlying context) in order to avoid rewriting internal methods.
      def context = outbound_context

      # Accepts either two positional arguments (key, value) or a hash of key/value pairs
      def expose(*args, **kwargs)
        if args.any?
          if args.size != 2
            raise ArgumentError,
                  "expose must be called with exactly two positional arguments (or a hash of key/value pairs)"
          end

          kwargs.merge!(args.first => args.last)
        end

        kwargs.each do |key, value|
          raise Action::Contract::InvalidExposure, key unless outbound_context.respond_to?(key)

          @context.public_send("#{key}=", value)
        end
      end
    end

    module ValidationInstanceMethods
      def apply_inbound_preprocessing!
        self.class.instance_variable_get("@inbound_preprocessing").each do |field, processor|
          new_value = processor.call(@context.public_send(field))
          @context.public_send("#{field}=", new_value)
        rescue StandardError => e
          raise PreprocessingError, "Error preprocessing field '#{field}': #{e.message}"
        end
      end

      def apply_inbound_defaults!
        self.class.instance_variable_get("@inbound_defaults").each do |field, default_value|
          unless @context.public_send(field)
            @context.public_send("#{field}=",
                                 default_value.respond_to?(:call) ? default_value.call : default_value)
          end
        end
      end

      def apply_outbound_defaults!
        self.class.instance_variable_get("@outbound_defaults").each do |field, default_value|
          unless @context.public_send(field)
            @context.public_send("#{field}=",
                                 default_value.respond_to?(:call) ? default_value.call : default_value)
          end
        end
      end

      def validate_context!(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless %i[inbound outbound].include?(direction)

        validations = self.class.instance_variable_get("@#{direction}_validations")
        context = direction == :inbound ? inbound_context : outbound_context

        ContractValidator.validate!(validations:, direction:, context:)
      end

      def context_for_logging(direction = nil)
        fields = case direction
                 when :inbound then self.class.instance_variable_get("@inbound_accessors")
                 when :outbound then self.class.instance_variable_get("@outbound_accessors")
                 else
                   self.class.instance_variable_get("@inbound_accessors") + self.class.instance_variable_get("@outbound_accessors")
                 end

        inspection_filter.filter(@context.to_h.slice(*fields))
      end

      protected

      def inspection_filter
        @inspection_filter ||= ActiveSupport::ParameterFilter.new(sensitive_fields)
      end

      def sensitive_fields
        self.class.instance_variable_get("@sensitive_fields").compact
      end
    end

    require "active_support/parameter_filter"

    class ContextFacadeInspector
      def initialize(interactor:, facade:, context:, direction:)
        @interactor = interactor
        @facade = facade
        @context = context
        @direction = direction
      end

      def class_name = "#{@direction.to_s.capitalize}ContextFacade"

      def call
        str = [status, visible_fields].compact_blank.join(" ")

        "#<#{@direction.to_s.capitalize}ContextFacade #{str}>"
      end

      private

      def status
        return unless @direction == :outbound
        return "[OK]" if @context.success?
        return "[failed with '#{@context.error}']" unless @context.exception

        %([failed with #{@context.exception.class.name}: '#{@context.exception.message}'])
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
                          elsif value.class.name == "ActiveRecord::Relation"
                            # Avoid hydrating full AR relation (i.e. avoid loading records just to report an error)
                            "#{value.name}::ActiveRecord_Relation"
                          else
                            value.inspect
                          end

        inspection_filter.filter_param(field, inspected_value)
      end

      def inspection_filter = @interactor.send(:inspection_filter)
    end

    class ContextFacade
      class ContextMethodNotAllowed < NoMethodError; end

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

      def inspect
        ContextFacadeInspector.new(interactor: @interactor, facade: self, context: @context, direction: @direction).call
      end

      delegate :success?, :failure?, :error, :exception, to: :@context
      def ok? = success?

      def success
        return unless success?

        @interactor.class.instance_variable_get("@success_message").presence || GENERIC_SUCCESS_MESSAGE
      end
      GENERIC_SUCCESS_MESSAGE = "Action completed successfully"

      def message = error || success

      def fail!(...) = raise ContextMethodNotAllowed,
                             "Cannot fail! directly -- either use fail_with or allow an exception to bubble up uncaught"

      private

      def exposure_method_name = @direction == :inbound ? :expects : :exposes

      INTERNALLY_USED_METHODS = %i[called! rollback! each_pair].freeze

      # Add nice error message for missing methods
      def method_missing(method_name, *args, &block)
        if @context.respond_to?(method_name)
          # Ideally Interactor base module would use @context rather than the context accessor
          # (since in our version, we want to disallow implementing services to directly access context).
          #
          # To avoid rewriting the methods directly to change to use @context, we redefine #context to
          # return the #outbound_context.  That's great for external access, but in the outbound context case
          # we need to allow the internal control methods to pass through.
          if @direction == :outbound && INTERNALLY_USED_METHODS.include?(method_name)
            return @context.send(method_name, *args, &block)
          end

          msg = <<~MSG
            Method ##{method_name} is not available on the #{@direction} context facade!

            #{@interactor.class.name || "The interactor"} is missing a line like:
              #{exposure_method_name} :#{method_name}
          MSG

          raise ContextMethodNotAllowed, msg
        end

        super
      end

      def respond_to_missing?(method_name, include_private = false)
        if @context.respond_to?(method_name)
          return @direction == :outbound && INTERNALLY_USED_METHODS.include?(method_name)
        end

        super
      end
    end
  end
end
