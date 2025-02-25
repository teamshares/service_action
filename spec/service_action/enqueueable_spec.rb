# frozen_string_literal: true

require "sidekiq/testing"
require_relative "../fixtures/enqueueable"

RSpec.describe ServiceAction::Enqueueable, type: :worker do
  context "Interactor" do
    subject { TestEnqueueableInteractor.enqueue(this: "this", that: "that") }

    describe "#enqueue" do
      it "queues job to the default queue" do
        expect(TestEnqueueableInteractor.queue).to eq("default")
      end

      it "sets the options" do
        expect(TestEnqueueableInteractor.sidekiq_options_hash).to include("retry" => 10, "queue" => "default", "retry_queue" => "low")
      end

      it "performs later" do
        expect(TestEnqueueableInteractor).to receive(:perform_async).with(hash_including({ "this" => "this" }))
        subject
      end
    end

    describe "#enqueue" do
      subject do
        Sidekiq::Testing.inline! do
          TestEnqueueableInteractor.enqueue(this: "this", that: "that")
        end
      end

      it "calls the Interactor#call" do
        expect(TestEnqueueableInteractor).to receive(:call).with(hash_including({ "this" => "this" }))
        subject
      end
    end

    describe "#enqueue!" do
      subject do
        Sidekiq::Testing.inline! do
          TestEnqueueableInteractor.enqueue!(name: "Joe", address: "123 Nope")
        end
      end

      it "performs later" do
        expect(TestEnqueueableInteractor).to receive(:call!).with(hash_including({ "name" => "Joe" }))
        subject
      end

      it "sets the context with the passed-in hash args" do
        expect { subject }.to output("Name: Joe\nAddress: 123 Nope\n").to_stdout
      end
    end
  end

  context "Organizer" do
    subject { TestEnqueueableOrganizer.enqueue(foo: "bar", name: "Joe", address: "123 Nope") }

    around do |example|
      Sidekiq::Testing.inline! do
        example.run
      end
    end

    describe "#enqueue" do
      it "queues job to the given queue" do
        expect(TestEnqueueableOrganizer.queue).to eq("high")
      end

      it "sets the options" do
        expect(TestEnqueueableOrganizer.sidekiq_options_hash).to include("retry" => 2, "queue" => "high", "retry_queue" => "medium")
      end

      it "sets the context with the passed-in hash args and calls all included Interactors" do
        expect { subject }.to output("Name: Joe\nAddress: 123 Nope\nAnother Interactor: bar\n").to_stdout
      end
    end
  end
end
