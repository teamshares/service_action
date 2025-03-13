# frozen_string_literal: true

require "action/contract"

RSpec.describe Action::Contract do
  let(:interactor) do
    build_interactor(described_class) do
      expects :foo, type: Numeric, numericality: { greater_than: 10 }
      exposes :bar

      def call
        foo * 10
      end
    end
  end

  context "when successful" do
    subject(:result) { interactor.call(foo: 11, bar: 12, baz: 13) }

    it "creates accessor" do
      is_expected.to be_success
      is_expected.to be_a(Action::ContextFacade)

      # Defined on context and allowed by outbound facade
      expect(subject.bar).to eq 12

      # Defined on context, but only allowed on inbound facade
      expect do
        subject.foo
      end.to raise_error(Action::ContractViolation::MethodNotAllowed)

      # Defined on context, but blocked by facade
      expect do
        subject.baz
      end.to raise_error(Action::ContractViolation::MethodNotAllowed)

      # Not defined at all on context
      expect { subject.quz }.to raise_error(NoMethodError)
    end

    describe "#inspect" do
      subject { result.inspect }

      it { is_expected.to eq("#<Action::Result [OK] bar: 12>") }
    end
  end

  context "inbound context facade inspect" do
    subject { interactor.call(foo: 11).the_internal_context.inspect }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, type: Numeric, numericality: { greater_than: 10 }
        exposes :the_internal_context

        def call
          expose :the_internal_context, internal_context
        end
      end
    end

    it { is_expected.to eq "#<Action::InternalContext foo: 11>" }
  end

  context "with validations" do
    subject { interactor.call(foo: 9, bar: 12, baz: 13) }

    it "fails inbound" do
      expect { subject }.to raise_error(Action::InboundValidationError)
    end
  end

  context "with missing inbound args" do
    subject { interactor.call(bar: 12, baz: 13) }

    it "fails inbound" do
      expect { subject }.to raise_error(Action::InboundValidationError)
    end
  end

  context "with outbound missing" do
    subject { interactor.call(foo: 11, baz: 13) }

    it "fails" do
      expect { subject }.to raise_error(Action::OutboundValidationError)
    end
  end

  context "allow_blank is passed to further validators as well" do
    subject { interactor.call(baz: 13) }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, type: Numeric, numericality: { greater_than: 10 }, allow_blank: true
        exposes :bar, allow_blank: true
      end
    end

    it { is_expected.to be_success }
  end

  context "inbound defaults" do
    subject { interactor.call }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, type: Numeric, default: 99
        exposes :foo
      end
    end

    it "are set correctly" do
      is_expected.to be_success
      expect(subject.foo).to eq 99
    end
  end

  context "outbound defaults" do
    subject { interactor.call }

    let(:interactor) do
      build_interactor(described_class) do
        exposes :foo, default: 99
      end
    end

    it "are set correctly" do
      is_expected.to be_success
      expect(subject.foo).to eq 99
    end
  end

  context "can expose" do
    subject { interactor.call }

    let(:interactor) do
      build_interactor(described_class) do
        exposes :qux

        def call
          expose :qux, 99
        end
      end
    end

    it "can expose" do
      is_expected.to be_success
      expect(subject.qux).to eq 99
    end
  end

  context "type validation accepts array of types" do
    subject { interactor.call(foo:) }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, type: [String, Numeric]
      end
    end

    context "when valid" do
      let(:foo) { 123 }
      it { is_expected.to be_success }
    end

    context "when invalid" do
      let(:foo) { Object.new }
      it {
        expect do
          subject
        end.to raise_error(Action::InboundValidationError, "Foo is not one of String, Numeric")
      }
    end

    context "when false" do
      let(:foo) { false }
      it { expect { subject }.to raise_error(Action::InboundValidationError, "Foo can't be blank") }
    end
  end

  context "explicit presence settings override implicit validation" do
    subject { interactor.call(foo:) }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, boolean: true
      end
    end

    context "when false" do
      let(:foo) { false }
      it { is_expected.to be_success }
    end

    context "when nil" do
      let(:foo) { nil }
      it {
        expect { subject }.to raise_error(Action::InboundValidationError, "Foo must be true or false")
      }
    end
  end

  context "multiple fields validations per call" do
    subject { interactor.call(foo:, bar:) }

    let(:foo) { 1 }
    let(:bar) { 2 }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, :bar, type: { with: Numeric, message: "should numberz" }
      end
    end

    context "when one invalid" do
      let(:bar) { "string" }
      it { expect { subject }.to raise_error(Action::InboundValidationError, "Bar should numberz") }
    end

    context "when set" do
      it { is_expected.to be_success }
    end
  end

  context "support optional outbound exposures" do
    subject { interactor.call(foo:) }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, boolean: true
        exposes :bar, allow_blank: true

        def call
          expose :bar, 99 if foo
        end
      end
    end

    context "when not set" do
      let(:foo) { false }
      it { is_expected.to be_success }
    end

    context "when set" do
      let(:foo) { true }
      it { is_expected.to be_success }
    end
  end

  describe "preprocessing" do
    subject { interactor.call(date_as_date: input) }

    let(:interactor) do
      build_interactor(described_class) do
        expects :date_as_date, type: Date, preprocess: ->(raw) { Date.parse(raw) }
        exposes :date_as_date

        def call
          expose date_as_date:
        end
      end
    end

    context "when preprocessing is successful" do
      let(:input) { "2020-01-01" }

      it "modifies the context" do
        is_expected.to be_success
        expect(subject.date_as_date).to be_a(Date)
      end
    end

    context "when preprocessing fails" do
      let(:input) { "" }

      it "raises" do
        expect { subject }.to raise_error(Action::ContractViolation::PreprocessingError)
      end
    end
  end

  describe "with custom validations" do
    subject { interactor.call(foo:) }

    let(:foo) { 20 }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, validate: ->(value) { "must be pretty big" unless value > 10 }
      end
    end

    context "when valid" do
      it { is_expected.to be_success }
    end

    context "when invalid" do
      let(:foo) { 10 }
      it { expect { subject }.to raise_error(Action::InboundValidationError, "Foo must be pretty big") }
    end

    context "when validator raises" do
      let(:interactor) do
        build_interactor(described_class) do
          expects :foo, validate: ->(_value) { raise "oops" }
        end
      end

      it {
        expect do
          subject
        end.to raise_error(Action::InboundValidationError, "Foo failed validation: oops")
      }
    end
  end

  describe "accepts multiple fields per expects line" do
    subject { interactor.call(foo:, bar:) }

    let(:interactor) do
      build_interactor(described_class) do
        expects :foo, :bar, type: Numeric
      end
    end

    context "when valid" do
      let(:foo) { 1 }
      let(:bar) { 2 }
      it { is_expected.to be_success }
    end

    context "when invalid" do
      let(:foo) { 1 }
      let(:bar) { "string" }
      it { expect { subject }.to raise_error(Action::InboundValidationError, "Bar is not a Numeric") }
    end
  end
end
