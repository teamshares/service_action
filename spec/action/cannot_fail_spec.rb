# frozen_string_literal: true

RSpec.describe Action do
  context "calling fail! on context" do
    subject { action.call }

    let(:action) do
      build_action do
        def call
          context.fail!("User-facing error")
        end
      end
    end

    it "is prevented" do
      is_expected.not_to be_success
      expect(subject.error).to eq("Something went wrong")
      expect(subject.exception).to be_a(Action::ContextFacade::MethodNotAllowed)
      expect(subject.exception.message).to eq "Cannot fail! directly -- either use fail_with or allow an exception to bubble up uncaught"
    end
  end
end
