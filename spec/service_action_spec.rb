# frozen_string_literal: true

RSpec.describe ServiceAction do
  it "has a version number" do
    expect(ServiceAction::VERSION).not_to be nil
  end
end
