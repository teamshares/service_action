RSpec.describe "Logging" do
  def build_interactor(&block)
    interactor = Class.new.send(:include, ServiceAction)
    interactor.class_eval(&block) if block
    interactor
  end

  let(:interactor) do
    build_interactor do
      expects :level, default: :info
      def call
        log("Hello, World!", level:)
      end
    end
  end
  let(:level) { :info }
  let(:logger) { instance_double(Logger, debug: nil, info: nil, error: nil, warn: nil, fatal: nil) }

  subject { interactor.call(level:) }

  before do
    allow(interactor).to receive(:logger).and_return(logger)
  end

  it "logs" do
    expect(logger).to receive(:info).with("[Anonymous Class] Hello, World!")
    is_expected.to be_success
  end

  ServiceAction::Logging::LEVELS.each do |level|
    describe "##{level}" do
      let(:level) { level }

      it "delegates via #log" do
        expect(logger).to receive(level).with("[Anonymous Class] Hello, World!")
        is_expected.to be_success
      end
    end
  end

  describe "with .targeted_for_debug_logging?" do
    let(:level) { :debug }

    before do
      allow(interactor).to receive(:targeted_for_debug_logging?).and_return(targeted_for_debug_logging)
    end

    context "false" do
      let(:targeted_for_debug_logging) { false }
      it "logs debug at debug level" do
        expect(logger).to receive(:debug).with("[Anonymous Class] Hello, World!")
        is_expected.to be_success
      end
    end

    context "true" do
      let(:targeted_for_debug_logging) { true }
      it "logs debug at info level" do
        expect(logger).to receive(:info).with("[Anonymous Class] Hello, World!")
        is_expected.to be_success
      end
    end
  end
end
