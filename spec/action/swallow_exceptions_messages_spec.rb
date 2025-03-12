# frozen_string_literal: true

RSpec.describe Action do
  describe "#error_message configuration (for #error when swallowing exceptions)" do
    let(:klass) { nil }

    let(:action) do
      build_action do
        expects :klass, allow_blank: true

        success_message "great news"

        error_message "baseline message", RuntimeError => "RUN RUN RUN"
        error_message ArgumentError, ->(e) { "Bad args: #{e.message}" }

        def call
          return if klass.blank?

          raise klass, "Pretending something went wrong"
        end
      end
    end

    subject { action.call(klass:) }

    it { is_expected.to be_success }
    it { expect(subject.success).to eq("great news") }
    it { expect(subject.message).to eq("great news") }
    it { expect(action.generic_error_message).to eq("baseline message") }

    context "with RuntimeError" do
      let(:klass) { RuntimeError }

      it { is_expected.to be_failure }
      it { expect(subject.error).to eq("RUN RUN RUN") }
      it { expect(subject.message).to eq("RUN RUN RUN") }
    end

    context "with ArgumentError" do
      let(:klass) { ArgumentError }

      it { is_expected.to be_failure }
      it { expect(subject.error).to eq("Bad args: Pretending something went wrong") }
      it { expect(subject.message).to eq("Bad args: Pretending something went wrong") }
    end

    context "with other error" do
      let(:klass) { StandardError }

      it { is_expected.to be_failure }
      it { expect(subject.error).to eq("baseline message") }
      it { expect(subject.message).to eq("baseline message") }
    end
  end
end
