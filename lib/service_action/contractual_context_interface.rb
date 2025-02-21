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
        @inbound_validations = Hash.new { |h, k| h[k] = {} }
        @outbound_validations = Hash.new { |h, k| h[k] = {} }

        extend ClassMethods
        include InstanceMethods
        include ValidationInstanceMethods

        # Remove public context accessor
        remove_method :context

        around do |hooked|
          puts "validations before"
          validate_context!(:inbound)
          hooked.call
          validate_context!(:outbound)
          puts "validations end"
        end
      end
    end

    module ClassMethods
      def expects(field, type = nil, allow_blank: false, **additional_validations)
        @inbound_accessors << field

        @inbound_validations[field][:presence] = true unless allow_blank
        @inbound_validations[field][:type] = type if type.present?
        @inbound_validations[field].merge!(additional_validations) if additional_validations.present?

        field
      end

      def exposes(field, type = nil, allow_blank: false, **additional_validations)
        @outbound_accessors << field

        @outbound_validations[field][:presence] = true unless allow_blank
        @outbound_validations[field][:type] = type if type.present?
        @outbound_validations[field].merge!(additional_validations) if additional_validations.present?

        field
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
          raise ArgumentError, "expose must be called with exactly two positional arguments (or a hash of key/value pairs)" if args.size != 2

          kwargs.merge!(args.first => args.last)
        end

        # TODO: handle collisions with already-existing vars!

        kwargs.each do |key, value|
          if outbound_context.respond_to?(key)
            @context.public_send("#{key}=", value)
          else
            raise InvalidExposureAttempt, "Attempted to expose unknown key '#{key}': be sure to declare it with `exposes :#{key}`"
          end
        end
      end
    end

    module ValidationInstanceMethods
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

      class TypeValidator < ActiveModel::EachValidator
        def validate_each(record, attribute, value)
          return if value.blank? # Handled with a separate default presence validator

          type = options[:with]
          record.errors.add attribute, (options[:message] || "is not a #{type}") unless value.is_a?(type)
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
          self.singleton_class.define_method(field) { @context.public_send(field) }
        end

        # TODO: inspect or to_s?
        self.singleton_class.define_method(:inspect) do
          visible_layer = allowed_fields.map { |field| "#{field}: #{self.public_send(field).inspect}" }.join(", ")

          "#<#{self.class.name.split('::').last} (#{direction}) #{visible_layer}>"
        end
      end

      # I HOPE this doesn't cause unexpected behavior -- we need this to avoid rescuing
      # Failures arising from other contexts in Interactor#run
      def object_id = @context.object_id

      def_delegators :@context, :success?, :failure?, :fail!, :error, :exception
      def ok? = success?

      private

      def exposure_method_name = @direction == :inbound ? :expects : :exposes

      INTERNALLY_USED_METHODS = %i[called! fail! rollback!]

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

          msg =<<~MSG
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
