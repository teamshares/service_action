# frozen_string_literal: true

RSpec.describe "Organizing" do
  describe "accepts procs" do
    let(:organizer) do
      Class.new do
        include ServiceAction::Organizer

        organize(
          lambda { |name:|
            # log("hi, #{name}")
          }
        )
      end
    end

    context "when given expected arguments" do
      it "execute as expected" do
        result = organizer.call(name: "kali")

        expect(result).to be_success
      end
    end

    context "when missing expected arguments" do
      it "fails with the expected invalid-context error" do
        result = organizer.call

        expect(result).not_to be_success
        expect(result.exception).to be_a(ServiceAction::InboundContractViolation)
        expect(result.exception.message).to eq("Name can't be blank")
      end
    end
  end

  describe "conditionally skips execution" do
    let(:organizer) do
      Class.new do
        include ServiceAction::Organizer

        organize(
          { action: -> { log("step one") }, if: true },
          { action: -> { log("step two") }, if: false },
          { action: -> { log("step three") }, if: -> { false } },
          { action: -> { log("step four") }, if: -> { true } }
        )
      end
    end

    it "skips steps based on condition" do
      result = organizer.call

      # TODO: add checks that things got skipped
      expect(result).to be_success
    end
  end

  describe "accepts configuration per step" do
    describe "accepts configuration per step" do
      describe "{ critical: false } with internal failure" do
        let(:organizer) do
          Class.new do
            include ServiceAction::Organizer

            organize(
              {
                action: -> { raise "oops" },
                critical: false
              }
            )
          end
        end

        it "logs but does not fail organizer" do
          result = organizer.call

          expect(result).to be_success
        end
      end
    end

    # describe "{ critical: false } with keyword parsing failure" do
    #   let(:organizer) do
    #     Class.new do
    #       include ServiceAction::Organizer

    #       organize(
    #         {
    #           action: ->(name:) { raise "oops" },
    #           critical: false
    #         }
    #       )
    #     end
    #   end

    #   context "when given expected arguments" do
    #     it "execute as expected" do
    #       result = organizer.call(name: "kali")

    #       expect(result).to be_success
    #     end
    #   end

    #   context "when missing expected arguments" do
    #     it "logs but does not fail organizer" do
    #       # result = organizer.call
    #       result = organizer.call(name: "kali")

    #       expect(result).to be_success
    #     end
    #   end
    # end
  end

  # let(:organizer) do
  #   Class.new do
  #     class SubA
  #       include ServiceAction

  #       expects :date, type: String
  #       exposes :date, type: Date

  #       def call
  #         expose date: Date.parse(date)
  #       end
  #     end

  #     class SubB
  #       include ServiceAction

  #       expects :date, type: Date
  #       exposes :year, type: Integer

  #       def call
  #         expose :year, date.year
  #       end
  #     end

  #     include ServiceAction::Organizer
  #     expects :name, type: String
  #     # exposes :year, type: Integer

  #     organize(
  #       [->(name:) { puts("hi, #{name}") }, { foo: 1 }]
  #       # [SubA, { critical: false }],
  #       # [->(date:) { Date.parse(date) }, { foo: 1 }],
  #       # [SubB]
  #       # { action: SubB, critical: false }
  #     )
  #   end
  # end

  # it "organizes the modules" do
  #   # result = organizer.call(date: "2020-01-01")
  #   result = organizer.call(name: "kali")

  #   expect(result).to be_success
  #   # expect(result.year).to eq(2020)
  # end
end
