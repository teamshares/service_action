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
          validate_contract!(:inbound)
          hooked.call
          apply_outbound_defaults!
          validate_contract!(:outbound)
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
              v = { value: v } unless v.is_a?(Hash)
              { allow_blank: true }.merge(v)
            end
          else
            # TODO: do we need to merge allow_blank into all _other_ validations' options?
            @inbound_validations[field][:presence] = !additional_validations.key?(:boolean)
          end

          # TODO: do we need to merge allow_blank into all subsequent validations' options?
          @inbound_validations[field].merge!(additional_validations) if additional_validations.present?

          # Allow local access to explicitly-expected fields
          define_method(field) { internal_context.public_send(field) }

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
              v = { value: v } unless v.is_a?(Hash)
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
        allowed_fields = self.class.instance_variable_get("@#{direction}_accessors").compact

        klass.new(action: self, context: @context, allowed_fields:)
      end
    end

    module ValidationInstanceMethods
      def apply_inbound_preprocessing!
        self.class.instance_variable_get("@inbound_preprocessing").each do |field, processor|
          new_value = processor.call(@context.public_send(field))
          @context.public_send("#{field}=", new_value)
        rescue StandardError => e
          raise Action::ContractViolation::PreprocessingError, "Error preprocessing field '#{field}': #{e.message}"
        end
      end

      def apply_inbound_defaults! = apply_defaults! self.class.instance_variable_get("@inbound_defaults")
      def apply_outbound_defaults! = apply_defaults! self.class.instance_variable_get("@outbound_defaults")

      def validate_contract!(direction)
        raise ArgumentError, "Invalid direction: #{direction}" unless %i[inbound outbound].include?(direction)

        validations = self.class.instance_variable_get("@#{direction}_validations")
        context = direction == :inbound ? internal_context : external_context

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

      private

      def apply_defaults!(defaults_mapping)
        defaults_mapping.each do |field, default_value|
          unless @context.public_send(field)
            @context.public_send("#{field}=",
                                 default_value.respond_to?(:call) ? default_value.call : default_value)
          end
        end
      end
    end
  end
end
