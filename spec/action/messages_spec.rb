# frozen_string_literal: true

RSpec.describe Action do
  describe "#messages configuration" do
    subject(:result) { action.call }

    describe "fail_prefix" do
      subject { result.error }

      context "when static" do
        let(:action) do
          build_action do
            messages(fail_prefix: "PREFIX")
            def call
              fail! "a message"
            end
          end
        end

        it { expect(result).not_to be_ok }
        it { is_expected.to eq("PREFIX a message") }
      end
    end

    describe "success message" do
      subject { result.success }

      context "when static" do
        let(:action) do
          build_action do
            messages(success: "Great news!")
          end
        end

        it { expect(result).to be_ok }
        it { is_expected.to eq("Great news!") }
      end

      context "when dynamic" do
        let(:action) do
          build_action do
            expects :foo, default: "bar"
            messages(success: -> { "Great news: #{@var} from #{foo}" })

            def call
              @var = 123
            end
          end
        end

        it { expect(result).to be_ok }
        it "is evaluated within internal context + expected vars" do
          is_expected.to eq("Great news: 123 from bar")
        end
      end

      context "when dynamic with exposed vars" do
        let(:action) do
          build_action do
            exposes :foo, default: "bar"
            messages(success: -> { "Great news: #{@var} from #{foo}" })

            def call
              expose foo: "baz"
              @var = 123
            end
          end
        end

        it { expect(result).to be_ok }
        it "is evaluated within internal context + expected vars" do
          is_expected.to eq("Great news: 123 from baz")
        end
      end

      context "when dynamic raises error" do
        let(:action) do
          build_action do
            expects :foo, default: "bar"
            messages(
              default_success: "much success",
              success: -> { "Great news: #{@var} from #{foo} and #{some_undefined_var}" }
            )

            def call
              @var = 123
            end
          end
        end

        it { expect(result).to be_ok }
        it "falls back to default success" do
          is_expected.to eq("much success")
        end
      end

      context "when dynamic returns nil" do
        let(:action) do
          build_action do
            messages(default_success: "OK")
            messages(success: -> { "" })
          end
        end

        it { expect(result).to be_ok }
        it "falls back to default" do
          is_expected.to eq("OK")
        end
      end
    end

    describe "error message" do
      subject { result.error }

      context "when static" do
        let(:action) do
          build_action do
            expects :missing_param
            messages(error: "Great news!")
          end
        end

        it { expect(result).not_to be_ok }
        it { is_expected.to eq("Great news!") }
      end

      context "when dynamic" do
        let(:action) do
          build_action do
            expects :missing_param
            messages(error: -> { "Great news: #{@var}" })

            def call
              @var = 123
            end
          end
        end

        it { expect(result).not_to be_ok }
        it "is evaluated within internal context" do
          is_expected.to eq("Great news: ")
        end
      end

      context "when dynamic wants exception" do
        let(:action) do
          build_action do
            expects :missing_param
            messages(error: ->(e) { "Great news: #{e.class.name}" })
          end
        end

        it { expect(result).not_to be_ok }
        it "is evaluated within internal context" do
          is_expected.to eq("Great news: Action::InboundValidationError")
        end
      end

      context "when dynamic returns nil" do
        let(:action) do
          build_action do
            expects :missing_param
            messages(default_error: "OK")
            messages(error: -> { "" })
          end
        end

        it { expect(result).not_to be_ok }
        it "falls back to default" do
          is_expected.to eq("OK")
        end
      end
    end
  end
end
