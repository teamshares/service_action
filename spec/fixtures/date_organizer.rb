# frozen_string_literal: true

# These classes are only used to test organizers (`let`-ed anonymous classes don't play well with organizing)

class DateParser
  include Action

  expects :date, type: String
  exposes :date, type: Date

  def call
    expose date: Date.parse(date)
  end

  messages error: "Parsing the date went poorly"
end

class DateEvaluator
  include Action

  expects :date, type: Date
  exposes :year, type: Integer

  def call
    expose :year, date.year
  end
end

class VanillaOrganizer
  include Interactor::Organizer

  organize DateParser, DateEvaluator
end

class ServiceActionOrganizer
  include Action::Organizer

  expects :date, type: String
  exposes :year, type: Integer

  organize DateParser, DateEvaluator
end
