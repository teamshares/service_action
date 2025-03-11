# frozen_string_literal: true

RSpec.describe Action do
  describe "#on_exception" do
    subject { interactor.call(name: "Foo", ssn: "abc", extra: "bang", outbound: 1) }

    before do
      allow(described_class.config).to receive(:on_exception)
    end

    let(:interactor) do
      build_action do
        expects :name
        expects :ssn, sensitive: true
        exposes :outbound

        def call
          raise "Some internal issue!"
        end
      end
    end

    let(:filtered_context) do
      { name: "Foo", ssn: "[FILTERED]", outbound: 1 }
    end

    it "is given a filtered context (sensitive values filtered + only declared inbound/outbound fields)" do
      expect(described_class.config).to receive(:on_exception).with(anything,
                                                                    context: filtered_context).and_call_original
      is_expected.not_to be_success
    end
  end

  describe "#noncritical" do
    subject { interactor.call }

    let(:interactor) do
      build_action do
        def self.on_exception(exception, context:); end

        expects :should_fail_with, allow_blank: true, default: false

        def call
          noncritical do
            fail_with "allow intentional failure to bubble" if should_fail_with
            raise "Some internal issue!"
          end
        end
      end
    end

    it "calls on_exception but doesn't fail interactor" do
      expect(described_class.config).to receive(:on_exception).once
      is_expected.to be_success
    end

    context "with an explicit fail_with" do
      subject { interactor.call(should_fail_with: true) }

      it "allows the failure to bubble up" do
        expect(interactor).not_to receive(:on_exception)
        is_expected.not_to be_success
        expect(subject.error).to eq("allow intentional failure to bubble")
      end
    end
  end
end
