# frozen_string_literal: true

# Shared examples for a rack endpoint that returns surveys according to survey-level refiring limits
RSpec.shared_examples "rack refire limiter" do
  let(:account) { create(:account) }

  def make_call(account)
    raise NotImplementedError, "You must implement 'make_call' to use 'rack frequency capped serving'"
  end

  def it_should_return_survey
    json_response = make_call(account)

    # TODO: Validate a schema or something
    expect(json_response).not_to eq({})
  end

  def it_should_not_return_survey
    json_response = make_call(account)

    assert_valid_schema RackSchemas::Common::NoSurveyFoundResponseSchema, json_response
  end

  describe "refire" do
    let(:last_fired_minutes_ago) { 2 }

    before do
      @survey = create(:survey, refire_time: refire_time, refire_time_period: 'minutes', refire_enabled: true, account: account)

      device = create(:device, udid: udid)
      submission = create(:submission, device_id: device.id, survey_id: @survey.id, created_at: last_fired_minutes_ago.minutes.ago)
      create(:answer, question: @survey.reload.questions.first, possible_answer: @survey.reload.questions.first.possible_answers.first, submission: submission)
    end

    context "when now > refire_time" do
      let(:refire_time) { last_fired_minutes_ago - 1 }

      it "refires" do
        it_should_return_survey
      end
    end

    context "when now < refire_time" do
      let(:refire_time) { last_fired_minutes_ago + 1 }

      it "does not refire" do
        it_should_not_return_survey
      end
    end

    context "when refire is disabled" do
      let(:refire_time) { last_fired_minutes_ago - 1 }

      before do
        @survey.update(refire_enabled: false)
      end

      it "does not refire" do
        it_should_not_return_survey
      end
    end
  end
end
