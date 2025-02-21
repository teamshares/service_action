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
      exposes :bar

      def call
        foo * 10
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

  context "with missing inbound args" do
    subject { interactor.call(bar: 12, baz: 13) }

    it "fails inbound" do
      expect { subject }.to raise_error(ServiceAction::InboundContractViolation)
    end
  end

  context "with outbound missing" do
    subject { interactor.call(foo: 11, baz: 13) }

    it "fails" do
      expect { subject }.to raise_error(ServiceAction::OutboundContractViolation)
    end
  end

  context "allow_blank" do
    subject { interactor.call(foo: nil, bar: nil, baz: 13) }

    let(:interactor) {
      build_interactor do
        expects :foo, Numeric, allow_blank: true
        exposes :bar, allow_blank: true
      end
    }

    it { is_expected.to be_success }
  end

  context "inbound defaults" do
    subject { interactor.call }

    let(:interactor) {
      build_interactor do
        expects :foo, Numeric, default: 99
        exposes :foo
      end
    }

    it "are set correctly" do
      is_expected.to be_success
      expect(subject.foo).to eq 99
    end
  end

  context "outbound defaults" do
    subject { interactor.call }

    let(:interactor) {
      build_interactor do
        exposes :foo, default: 99
      end
    }

    it "are set correctly" do
      is_expected.to be_success
      expect(subject.foo).to eq 99
    end
  end

  context "can expose" do
    subject { interactor.call }

    let(:interactor) {
      build_interactor do
        exposes :qux

        def call
          expose :qux, 99
        end
      end
    }

    it "can expose" do
      is_expected.to be_success
      expect(subject.qux).to eq 99
    end
  end
end
