# frozen_string_literal: true

require "active_model"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"

require "action/contract_validator"
require "action/context_facade"

module Action
  module Contract
    def self.included(base)
      base.class_eval do
        class_attribute :internal_field_configs, :external_field_configs
        self.internal_field_configs ||= []
        self.external_field_configs ||= []

        extend ClassMethods
        include InstanceMethods
        include ValidationInstanceMethods

        # Remove public context accessor
        remove_method :context

        around do |hooked|
          apply_inbound_preprocessing!
          apply_defaults!(:inbound)
          validate_contract!(:inbound)
          hooked.call
          apply_defaults!(:outbound)
          validate_contract!(:outbound)
        end
      end
    end

    FieldConfig = Data.define(:field, :validations, :default, :preprocess, :sensitive)

    module ClassMethods
      def expects(*fields, allow_blank: false, default: nil, preprocess: nil, sensitive: false,
                  **validations)
        # Allow local access to explicitly-expected fields
        fields.each do |field|
          define_method(field) { internal_context.public_send(field) }
        end

        parse_field_configs(*fields, allow_blank:, default:, preprocess:, sensitive:, **validations).tap do |configs|
          duplicated = internal_field_configs.map(&:field) & configs.map(&:field)
          raise Action::DuplicateFieldError, "Duplicate field(s) declared: #{duplicated.join(", ")}" if duplicated.any?

          # NOTE: the dup may be unnecessary, but being careful to avoid letting a child's config modify the parent value
          # (children get their own class_attribute, BUT if the value is mutated we're just modifying the same object)
          self.internal_field_configs = self.internal_field_configs.dup + configs
        end
      end

      def exposes(*fields, allow_blank: false, default: nil, sensitive: false, **validations)
        parse_field_configs(*fields, allow_blank:, default:, preprocess: nil, sensitive:, **validations).tap do |configs|
          duplicated = external_field_configs.map(&:field) & configs.map(&:field)
          raise Action::DuplicateFieldError, "Duplicate field(s) declared: #{duplicated.join(", ")}" if duplicated.any?

          # NOTE: the dup may be unnecessary, but being careful to avoid letting a child's config modify the parent value
          # (children get their own class_attribute, BUT if the value is mutated we're just modifying the same object)
          self.external_field_configs = self.external_field_configs.dup + configs
        end
      end

      private

      def parse_field_configs(*fields, allow_blank: false, default: nil, preprocess: nil, sensitive: false,
                              **validations)
        if allow_blank
          validations.transform_values! do |v|
            v = { value: v } unless v.is_a?(Hash)
            { allow_blank: true }.merge(v)
          end
        elsif validations.key?(:boolean)
          validations[:presence] = false
        else
          validations[:presence] = true unless validations.key?(:presence)
        end

        fields.map { |field| FieldConfig.new(field:, validations:, default:, preprocess:, sensitive:) }
      end
    end

    module InstanceMethods
      def internal_context = @internal_context ||= build_context_facade(:inbound)
      def external_context = @external_context ||= build_context_facade(:outbound)

      # NOTE: ideally no direct access from client code, but we need to expose this for internal Interactor methods
      # (and passing through control methods to underlying context) in order to avoid rewriting internal methods.
      def context = external_context

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
          raise Action::ContractViolation::InvalidExposure, key unless external_context.respond_to?(key)

          @context.public_send("#{key}=", value)
        end
      end

      private

      def build_context_facade(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless %i[inbound outbound].include?(direction)

        klass = direction == :inbound ? Action::InternalContext : Action::Result
        allowed_fields = declared_fields(direction)

        klass.new(action: self, context: @context, allowed_fields:)
      end
    end

    module ValidationInstanceMethods
      def apply_inbound_preprocessing!
        internal_field_configs.each do |config|
          next unless config.preprocess

          initial_value = @context.public_send(config.field)
          new_value = config.preprocess.call(initial_value)
          @context.public_send("#{config.field}=", new_value)
        rescue StandardError => e
          raise Action::ContractViolation::PreprocessingError, "Error preprocessing field '#{config.field}': #{e.message}"
        end
      end

      def validate_contract!(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless %i[inbound outbound].include?(direction)

        configs = direction == :inbound ? internal_field_configs : external_field_configs
        validations = configs.each_with_object({}) do |config, hash|
          hash[config.field] = config.validations
        end
        context = direction == :inbound ? internal_context : external_context
        exception_klass = direction == :inbound ? Action::InboundValidationError : Action::OutboundValidationError

        ContractValidator.validate!(validations:, context:, exception_klass:)
      end

      def apply_defaults!(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless %i[inbound outbound].include?(direction)

        configs = direction == :inbound ? internal_field_configs : external_field_configs
        defaults_mapping = configs.each_with_object({}) do |config, hash|
          hash[config.field] = config.default
        end.compact

        defaults_mapping.each do |field, default_value|
          unless @context.public_send(field)
            @context.public_send("#{field}=",
                                 default_value.respond_to?(:call) ? default_value.call : default_value)
          end
        end
      end

      def context_for_logging(direction = nil)
        inspection_filter.filter(@context.to_h.slice(*declared_fields(direction)))
      end

      protected

      def inspection_filter
        @inspection_filter ||= ActiveSupport::ParameterFilter.new(sensitive_fields)
      end

      def sensitive_fields
        (internal_field_configs + external_field_configs).select(&:sensitive).map(&:field)
      end

      def declared_fields(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless direction.nil? || %i[inbound outbound].include?(direction)

        configs = case direction
                  when :inbound then internal_field_configs
                  when :outbound then external_field_configs
                  else (internal_field_configs + external_field_configs)
                  end

        configs.map(&:field)
      end
    end
  end
end
