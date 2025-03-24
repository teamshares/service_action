# frozen_string_literal: true

# These classes are only used to test Enqueueable

class TestEnqueueableInteractor
  include Action
  queue_options retry: 10, retry_queue: "low"

  gets :name, :address

  def call
    puts "Name: #{name}"
    puts "Address: #{address}"
  end
end

class AnotherEnqueueableInteractor
  include Action
  queue_options retry: 10, retry_queue: "low"

  gets :foo

  def call
    puts "Another Interactor: #{foo}"
  end
end

class TestEnqueueableOrganizer
  include Action::Organizer

  queue_options queue: "high", retry: 2, retry_queue: "medium"
  organize TestEnqueueableInteractor, AnotherEnqueueableInteractor
end
