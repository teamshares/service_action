# frozen_string_literal: true

RSpec.describe Action do
  describe "#depends_on" do
    subject { action.call(subaction:) }

    let(:subaction) { build_action }

    let(:action) do
      build_action do
        expects :subaction
        def call
          depends_on(error_prefix: "Sub") { subaction.call }
        end
      end
    end

    it { is_expected.to be_ok }

    context "when the subaction fails" do
      let(:subaction) do
        build_action do
          def call = fail_with("subaction failed")
        end
      end

      it { is_expected.not_to be_ok }
      it { expect(subject.error).to eq("Sub: subaction failed") }
    end

    context "when the subaction is not an Action" do
      let(:subaction) { -> { "arbitrary logic" } }

      it { is_expected.not_to be_ok }
      # NOTE: no error_prefix, because the parent action called wrong, rather than bubbled failure from child
      it { expect(subject.error).to eq("Something went wrong") }
      it { expect(subject.exception).to be_a(ArgumentError) }
      it {
        expect(subject.exception.message).to eq("#depends_on is expected to wrap an Action call, but it returned a String instead")
      }

      context "and it raises" do
        let(:subaction) { -> { raise "subaction raised" } }

        before do
          expect(action).to receive(:warn).with("DependsOn block raised an exception: subaction raised")
        end

        it { is_expected.not_to be_ok }
        it { expect(subject.error).to eq("Sub: Something went wrong") }
        it { expect(subject.exception).to eq(nil) }
      end
    end

    context "when the depends_on not given a block" do
      let(:action) do
        build_action do
          expects :subaction
          def call
            depends_on(error_prefix: "Sub")
          end
        end
      end

      it { is_expected.not_to be_ok }
      it { expect(subject.exception).to be_a(ArgumentError) }
      it { expect(subject.exception.message).to eq("#depends_on must be given a block to execute") }
    end
  end
end
