# frozen_string_literal: true

# These classes are only used to test Enqueueable

class TestEnqueueableInteractor
  include ServiceAction
  queue_options retry: 10, retry_queue: "low"

  expects :name, :address

  def call
    puts "Name: #{name}"
    puts "Address: #{address}"
  end
end

class AnotherEnqueueableInteractor
  include ServiceAction
  queue_options retry: 10, retry_queue: "low"

  expects :foo

  def call
    puts "Another Interactor: #{foo}"
  end
end

class TestEnqueueableOrganizer
  include ServiceAction::Organizer

  queue_options queue: "high", retry: 2, retry_queue: "medium"
  organize TestEnqueueableInteractor, AnotherEnqueueableInteractor
end
