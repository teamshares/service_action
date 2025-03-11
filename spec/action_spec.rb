# frozen_string_literal: true

RSpec.describe Action do
  it "has a version number" do
    expect(ServiceAction::VERSION).not_to be nil
  end

  describe "inbound validation" do
    let(:action) do
      build_action do
        expects :foo, type: Numeric, numericality: { greater_than: 10 }
      end
    end

    context "success" do
      subject { action.call(foo: 11, bar: 5, baz: 1) }

      it { is_expected.to be_success }
    end

    context "contract failure" do
      subject { action.call(foo: 9, bar: 5, baz: 1) }

      it "fails" do
        expect(subject).to be_failure
        expect(subject.error).to eq("Something went wrong")
        expect(subject.exception).to be_a(Action::InboundContractViolation)
        expect(subject.exception.errors).to be_a(ActiveModel::Errors)
        expect(subject.exception.message).to eq("Foo must be greater than 10")
      end
    end
  end

  describe "outbound validation" do
    let(:action) do
      build_action do
        exposes :bar, type: Numeric, numericality: { greater_than: 10 }
        exposes :qux, type: Numeric

        def call
          expose :qux, 99
        end
      end
    end

    context "success" do
      subject { action.call(foo: 10, bar: 11, baz: 1) }

      it { is_expected.to be_success }

      it "exposes existing context" do
        expect(subject.bar).to eq(11)
      end

      it "exposes new values" do
        expect(subject.qux).to eq(99)
      end

      # TODO: should this be swallowed and just be_failure with an exception attached?
      it {
        expect do
          subject.foo
        end.to raise_error(Action::RestrictContextAccess::ContextFacade::ContextMethodNotAllowed)
      }
    end

    context "contract failure" do
      subject { action.call(foo: 10, bar: 9, baz: 1) }

      it "fails" do
        expect(subject).to be_failure
        expect(subject.error).to eq("Something went wrong")
        expect(subject.exception).to be_a(Action::OutboundContractViolation)
        expect(subject.exception.errors).to be_a(ActiveModel::Errors)
        expect(subject.exception.message).to eq("Bar must be greater than 10")
      end
    end

    context "setting failure" do
      subject { action.call(foo: 10, bar: 11, baz: 1) }

      let(:action) do
        build_action do
          exposes :bar, type: Numeric, numericality: { greater_than: 10 }

          def call
            expose :qux, 99
          end
        end
      end

      it "fails" do
        expect(subject).to be_failure
        expect(subject.error).to eq("Something went wrong")
        expect(subject.exception).to be_a(Action::InvalidExposureAttempt)
      end
    end
  end

  describe "complex validation" do
    let(:action) do
      build_action do
        expects :foo, type: String
        exposes :bar, type: String
      end
    end

    context "success" do
      subject { action.call(foo: "a", bar: "b", baz: "c") }

      it { is_expected.to be_success }
    end

    context "failure" do
      subject { action.call(foo: 1, bar: 2, baz: 3) }

      it "fails" do
        expect(subject).to be_failure
        expect(subject.error).to eq("Something went wrong")
        expect(subject.exception).to be_a(Action::InboundContractViolation)
        expect(subject.exception.errors).to be_a(ActiveModel::Errors)
        expect(subject.exception.message).to eq("Foo is not a String")
      end
    end
  end

  describe "return shape" do
    subject { action.call }

    context "when successful" do
      let(:action) { build_action {} }

      it "is ok" do
        is_expected.to be_success
      end
    end

    context "when fail_with (user facing error)" do
      let(:action) do
        build_action do
          def call
            fail_with("User-facing error")
          end
        end
      end

      it "is not ok" do
        is_expected.not_to be_success
        expect(subject.error).to eq("User-facing error")
        expect(subject.exception).to be_nil
      end
    end

    context "when exception raised" do
      let(:action) do
        build_action do
          def call
            raise "Some internal issue!"
          end
        end
      end

      it "is not ok" do
        expect { subject }.not_to raise_error
        is_expected.not_to be_success
        expect(subject.error).to eq("Something went wrong")
        expect(subject.exception).to be_a(RuntimeError)
        expect(subject.exception.message).to eq("Some internal issue!")
      end
    end
  end

  context "when attempt to fail! on context" do
    subject { action.call }

    let(:action) do
      build_action do
        def call
          context.fail!("User-facing error")
        end
      end
    end

    it "is not ok" do
      is_expected.not_to be_success
      expect(subject.error).to eq("Something went wrong")
      expect(subject.exception).to be_a(Action::RestrictContextAccess::ContextFacade::ContextMethodNotAllowed)
      expect(subject.exception.message).to eq "Cannot fail! directly -- either use fail_with or allow an exception to bubble up uncaught"
    end
  end

  describe ".call!" do
    context "with success" do
      let(:action) do
        build_action {}
      end

      it "is ok" do
        expect(action.call!).to be_success
      end
    end

    context "with exception" do
      let(:action) do
        build_action do
          def call
            raise ZeroDivisionError, "manual bad thing"
          end
        end
      end

      it "call" do
        result = action.call
        expect(result).not_to be_success
        expect(result.error).to eq("Something went wrong")
      end

      it "raises original exception" do
        expect { action.call! }.to raise_error(ZeroDivisionError, "manual bad thing")
      end
    end

    context "with user-facing failure" do
      let(:action) do
        build_action do
          def call
            fail_with "User-facing error"
          end
        end
      end

      it "call" do
        result = action.call
        expect(result).not_to be_success
        expect(result.error).to eq("User-facing error")
      end

      it "raises our own Failure class" do
        expect { action.call! }.to raise_error(described_class::Failure, "User-facing error")
      end
    end
  end
end
