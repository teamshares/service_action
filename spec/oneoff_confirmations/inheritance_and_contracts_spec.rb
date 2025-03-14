# frozen_string_literal: true

# TODO: was used for manual testing -- clean up or remove when done

# NOTE: requires upstream interactor branch for support -- see TODO in Gemfile

RSpec.describe "One-off confirmation: inheritance and contracts" do
  let(:base) do
    build_action do
      expects :foo, type: Numeric, numericality: { greater_than: 10 }
      exposes :bar, type: Numeric

      def call
        expose bar: foo * 10
      end
    end
  end

  let(:version_a) do
    Class.new(base) do
      expects :baz, default: 123
    end
  end

  let(:version_b) do
    Class.new(base) do
      expects :baz, default: 100
    end
  end

  it "works as expected" do
    config_ids = [base, version_a, version_b].map(&:internal_field_configs).map(&:object_id)
    expect(config_ids.uniq.size).to eq(3)
  end
end
