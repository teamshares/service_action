# frozen_string_literal: true

# These classes are only used to test organizers (`let`-ed anonymous classes don't play well with organizing)

class DateParser
  include Action

  gets :date, type: String
  sets :date, type: Date

  def call
    set date: Date.parse(date)
  end

  messages error: "Parsing the date went poorly"
end

class DateEvaluator
  include Action

  gets :date, type: Date
  sets :year, type: Integer

  def call
    set :year, date.year
  end
end

class VanillaOrganizer
  include Interactor::Organizer

  organize DateParser, DateEvaluator
end

class ServiceActionOrganizer
  include Action::Organizer

  gets :date, type: String
  sets :year, type: Integer

  organize DateParser, DateEvaluator
end
