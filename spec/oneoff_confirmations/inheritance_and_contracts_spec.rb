# frozen_string_literal: true

# TODO: was used for manual testing -- clean up or remove when done

# NOTE: requires upstream interactor branch for support -- see TODO in Gemfile

RSpec.describe "One-off confirmation: inheritance and contracts" do
  let(:base) do
    build_action do
      gets :foo, type: Numeric, numericality: { greater_than: 10 }
      sets :bar, type: Numeric

      def call
        set bar: foo * 10
      end
    end
  end

  let(:version_a) do
    Class.new(base) do
      gets :baz, default: 123
    end
  end

  let(:version_b) do
    Class.new(base) do
      gets :baz, default: 100
    end
  end

  it "does not modify other classes' configs when inheriting" do
    config_ids = [base, version_a, version_b].map(&:internal_field_configs).map(&:object_id)
    expect(config_ids.uniq.size).to eq(3)
  end
end
