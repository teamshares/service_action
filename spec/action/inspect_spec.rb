# frozen_string_literal: true

RSpec.describe Action do
  let(:action) do
    build_action do
      expects :foo, type: Numeric, numericality: { greater_than: 10 }
      expects :ssn, sensitive: true

      exposes :bar
      exposes :phone, sensitive: true
      exposes :the_inbound_context, sensitive: true

      def call
        expose :bar, foo * 10
        expose :phone, "123-456-7890"
        expose :the_inbound_context, inbound_context
        fail_with "intentional error" if foo == 13
      end
    end
  end

  let(:foo) { 11 }
  let(:result) { action.call(foo:, ssn: "abc") }

  context "inbound facade #inspect" do
    subject { result.the_inbound_context.inspect }

    it { is_expected.to eq "#<InboundContextFacade foo: 11, ssn: [FILTERED]>" }
  end

  context "outbound facade #inspect" do
    subject { result.inspect }

    context "when OK" do
      it {
        is_expected.to eq "#<OutboundContextFacade [OK] bar: 110, phone: [FILTERED], the_inbound_context: [FILTERED]>"
      }
    end

    context "when exception" do
      let(:foo) { 9 }

      it {
        is_expected.to eq "#<OutboundContextFacade [failed with Action::ContractViolation::InboundValidationError: 'Foo must be greater than 10'] bar: nil, phone: nil, the_inbound_context: nil>" # rubocop:disable Metrics/LineLength
      }
    end

    context "when failed" do
      let(:foo) { 13 }

      it {
        is_expected.to eq "#<OutboundContextFacade [failed with 'intentional error'] bar: 130, phone: [FILTERED], the_inbound_context: [FILTERED]>"
      }
    end
  end
end
