# frozen_string_literal: true

require "service_action/contractual_context_interface"

RSpec.describe "Validations" do
  def build_interactor(&block)
    interactor = Class.new.send(:include, Interactor)
    interactor = interactor.send(:include, ServiceAction::ContractualContextInterface)
    interactor.class_eval(&block) if block
    interactor
  end

  let(:interactor) {
    build_interactor do
      expects :foo, Numeric, numericality: { greater_than: 10 }
      provides :bar

      def call
        puts "In interactor: #{inbound_context.inspect}"
        puts "CTX:::: #{context.inspect}"
        puts "10 * #{inbound_context.foo} = #{inbound_context.foo * 10}"
      end
    end
  }

  context "when successful" do
    subject { interactor.call(foo: 11, bar: 12, baz: 13) }

    it "creates accessor" do
      is_expected.to be_success
      puts subject.inspect
      is_expected.to be_a(ServiceAction::ContractualContextInterface::ContextFacade)

      # Defined on context and allowed by outbound facade
      expect(subject.bar).to eq 12

      # Defined on context, but only allowed on inbound facade
      expect { subject.foo }.to raise_error(ServiceAction::ContractualContextInterface::ContextFacade::ContextMethodNotAllowed)

      # Defined on context, but blocked by facade
      expect { subject.baz }.to raise_error(ServiceAction::ContractualContextInterface::ContextFacade::ContextMethodNotAllowed)

      # Not defined at all on context
      expect { subject.quz }.to raise_error(NoMethodError)
    end
  end

  context "with validations" do
    subject { interactor.call(foo: 9, bar: 12, baz: 13) }

    it "fails inbound" do
      expect { subject }.to raise_error(ServiceAction::InboundContractViolation)
    end
  end

  context "allow_blank" do
    subject { interactor.call(foo: nil, bar: nil, baz: 13) }

    let(:interactor) {
      build_interactor do
        expects :foo, Numeric, allow_blank: true
        provides :bar, allow_blank: true
      end
    }

    it { is_expected.to be_success }
  end
end
