# frozen_string_literal: true

# TODO: just use ActiveSupport::Delegate?
require "forwardable"
require "active_model"

module ServiceAction
  class ContractViolationException < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super
    end

    def message
      errors.full_messages.to_sentence
    end
  end

  class InboundContractViolation < ContractViolationException; end
  class OutboundContractViolation < ContractViolationException; end
  class InvalidExposureAttempt < StandardError; end

  module ContractualContextInterface
    def self.included(base)
      base.class_eval do
        @inbound_accessors ||= []
        @outbound_accessors ||= []
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
          apply_inbound_defaults!
          validate_context!(:inbound)
          hooked.call
          apply_outbound_defaults!
          validate_context!(:outbound)
        end
      end
    end

    module ClassMethods
      def expects(*fields, allow_blank: false, default: nil, **additional_validations)
        fields.map do |field|
          @inbound_accessors << field

          allow_blank = true if additional_validations.has_key?(:boolean) # If we're using the boolean validator, we need to allow blank to let false get through
          @inbound_validations[field][:presence] = true unless allow_blank

          # TODO: do we need to merge allow_blank into all subsequent validations' options?
          @inbound_validations[field].merge!(additional_validations) if additional_validations.present?

          # Allow local access to explicitly-expected fields
          define_method(field) { inbound_context.public_send(field) }

          @inbound_defaults[field] = default if default.present?

          field
        end
      end

      def exposes(*fields, allow_blank: false, default: nil, **additional_validations)
        fields.map do |field|
          @outbound_accessors << field

          allow_blank = true if additional_validations.has_key?(:boolean) # If we're using the boolean validator, we need to allow blank to let false get through
          @outbound_validations[field][:presence] = true unless allow_blank
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

        # TODO: handle collisions with already-existing vars!

        kwargs.each do |key, value|
          if outbound_context.respond_to?(key)
            @context.public_send("#{key}=", value)
          else
            raise InvalidExposureAttempt,
                  "Attempted to expose unknown key '#{key}': be sure to declare it with `exposes :#{key}`"
          end
        end
      end
    end

    module ValidationInstanceMethods
      def apply_inbound_defaults!
        self.class.instance_variable_get("@inbound_defaults").each do |field, default_value|
          @context.public_send("#{field}=", default_value) unless @context.public_send(field)
        end
      end

      def apply_outbound_defaults!
        self.class.instance_variable_get("@outbound_defaults").each do |field, default_value|
          @context.public_send("#{field}=", default_value) unless @context.public_send(field)
        end
      end

      def validate_context!(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless %i[inbound outbound].include?(direction)

        directional_validations = self.class.instance_variable_get("@#{direction}_validations")
        directional_context = direction == :inbound ? inbound_context : outbound_context

        validator = Class.new(ContextValidator) do
          def self.name = "OneoffContextValidator"

          directional_validations.each do |field, field_validations|
            field_validations.each do |key, value|
              validates field, key => value
            end
          end
        end.new(directional_context)

        return if validator.valid?

        exception_klass = direction == :inbound ? InboundContractViolation : OutboundContractViolation
        raise exception_klass, validator.errors
      end
    end

    # TODO: this does not appear to be thread safe -- clearing validations whenever setting -_-
    class ContextValidator
      include ActiveModel::Validations

      def initialize(context)
        @context = context
      end

      def read_attribute_for_validation(attr)
        @context.public_send(attr)
      end

      class BooleanValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          return if [true, false].include?(value)

          record.errors.add(attribute, "must be true or false")
        end
      end

      class TypeValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          return if value.blank? # Handled with a separate default presence validator

          types = options[:in] || Array(options[:with])

          msg = types.size == 1 ? "is not a #{types.first}" : "is not one of #{types.join(', ')}"
          record.errors.add attribute, (options[:message] || msg) unless types.any? { |type| value.is_a?(type) }
        end
      end
    end

    class ContextFacade
      class ContextMethodNotAllowed < NoMethodError; end

      extend Forwardable

      def initialize(interactor, direction, context)
        @context = context
        @direction = direction
        @interactor = interactor

        allowed_fields = @interactor.class.instance_variable_get("@#{direction}_accessors")

        allowed_fields.compact.each do |field|
          singleton_class.define_method(field) { @context.public_send(field) }
        end

        singleton_class.define_method(:inspect) do
          visible_fields = allowed_fields.map { |field| "#{field}: #{public_send(field).inspect}" }.join(", ")
          status = if direction == :outbound
                     ex_type = @context.exception ? "#{@context.exception.class.name}: " : ""
                     ex_msg = @context.exception ? @context.exception.message : @context.error
                     %( [#{@context.success? ? "OK" : "failed with #{ex_type}'#{ex_msg}'"}])
                   end

          "#<#{direction.to_s.capitalize}#{self.class.name.split("::").last}#{status} #{visible_fields}>"
        end
      end

      # I HOPE this doesn't cause unexpected behavior -- we need this to avoid rescuing
      # Failures arising from other contexts in Interactor#run
      def object_id = @context.object_id

      def_delegators :@context, :success?, :failure?, :fail!, :error, :exception
      def ok? = success?

      private

      def exposure_method_name = @direction == :inbound ? :expects : :exposes

      INTERNALLY_USED_METHODS = %i[called! fail! rollback! each_pair].freeze

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
