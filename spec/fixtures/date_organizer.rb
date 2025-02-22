# frozen_string_literal: true

# These classes are only used to test organizers (`let`-ed anonymous classes don't play well with organizing)

class DateParser
  include ServiceAction

  expects :date, String
  exposes :date, Date

  def call
    expose date: Date.parse(date)
  end

  def self.generic_error_message = "Parsing the date went poorly"
end

class DateEvaluator
  include ServiceAction

  expects :date, Date
  exposes :year, Integer

  def call
    expose :year, date.year
  end
end

class VanillaOrganizer
  include Interactor::Organizer

  organize DateParser, DateEvaluator
end

class ServiceActionOrganizer
  include ServiceAction::Organizer

  expects :date, String
  exposes :year, Integer

  organize DateParser, DateEvaluator
end
