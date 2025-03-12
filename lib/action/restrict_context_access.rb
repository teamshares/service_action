# frozen_string_literal: true

require "active_model"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/delegation"

require "action/contract_validator"
require "action/context_facade"

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
          raise Action::Contract::Violation::InvalidExposure, key unless outbound_context.respond_to?(key)

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
          raise Action::Contract::Violation::PreprocessingError, "Error preprocessing field '#{field}': #{e.message}"
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

      def validate_contract!(direction)
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
  end
end
