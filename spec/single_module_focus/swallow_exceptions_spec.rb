# frozen_string_literal: true

require "action/swallow_exceptions"

RSpec.describe Action::SwallowExceptions do
  describe "return shape" do
    subject(:result) { interactor.call }

    context "when successful" do
      let(:interactor) { build_interactor(described_class) {} }

      it "is ok" do
        is_expected.to be_success
      end
    end

    context "when fail! (user facing error)" do
      let(:interactor) do
        build_interactor(described_class) do
          def call
            fail!("User-facing error")
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
      let(:interactor) do
        build_interactor(described_class) do
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

      context "with custom generic error message" do
        subject { result.error }

        before { interactor.error_message("Custom error message") }

        it "uses the generic override" do
          is_expected.to eq("Custom error message")
        end

        context "with per-exception-type overrides as string" do
          let(:interactor) do
            build_interactor(described_class) do
              error_message RuntimeError: "RUNTIME ERROR"

              def call
                raise "Some internal issue!"
              end
            end
          end

          it "uses the more specific override" do
            is_expected.to eq("RUNTIME ERROR")
          end
        end

        context "with per-exception-type overrides as callable" do
          let(:interactor) do
            build_interactor(described_class) do
              error_message RuntimeError => ->(e) { "RUNTIME: #{e.message}" }

              def call
                raise "Some internal issue!"
              end
            end
          end

          it "uses the more specific override" do
            is_expected.to eq("RUNTIME: Some internal issue!")
          end
        end
      end
    end
  end
end
