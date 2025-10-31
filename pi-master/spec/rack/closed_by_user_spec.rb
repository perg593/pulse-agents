# frozen_string_literal: true
require 'spec_helper'
require File.join(File.dirname(__FILE__), 'rack_app_spec_helper')

include RackAppSpecHelper

# Think of this as a mixin. You will need to provide lambdas for the following:
# empty_response - Judge whether the response had no survey
# custom_call - The call to the rack endpoint
shared_examples 'stop_showing_without_answer' do
  let(:udid) { '00000000-0000-4000-f000-000000000001' }
  let(:survey) { create(:survey_with_account) }

  # custom_call = lambda { |survey_id, account_identifier, udid, preview_mode| }
  def make_call(preview_mode: false)
    custom_call.call(survey.id, survey.account.identifier, udid, preview_mode)
  end

  # empty_response = lambda { |json_response| }
  def found_no_survey(json_response)
    expect(empty_response.call(json_response)).to eq({})
  end

  def found_survey?(json_response)
    expect(json_response.dig('survey', 'id')).to eq(survey.id)
  end

  describe 'as true' do
    describe 'with submission' do
      describe 'with closed_by_user as true' do
        before do
          survey.stop_showing_without_answer = true
          survey.save
        end

        it 'does not return the survey' do
          device = create(:device, udid: udid)
          create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: true)

          json_response = make_call
          found_no_survey(json_response)
        end

        it 'returns the survey if preview mode is on' do
          device = create(:device, udid: udid)
          create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: true)

          json_response = make_call(preview_mode: true)
          found_survey?(json_response)
        end

        it 'returns the survey if the submission is on another device' do
          another_udid = '00000000-0000-4000-f000-000000000002'
          device = create(:device, udid: another_udid)
          create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: true)

          json_response = make_call
          found_survey?(json_response)
        end
      end

      describe 'with closed_by_user as false' do
        it 'returns the survey' do
          device = create(:device, udid: udid)
          create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: false)

          json_response = make_call
          found_survey?(json_response)
        end
      end
    end

    describe 'without submission' do
      it 'returns the survey' do
        json_response = make_call
        found_survey?(json_response)
      end
    end
  end

  describe 'as false' do
    before do
      survey.stop_showing_without_answer = false
      survey.save
    end

    describe 'with submission with closed_by_user as true' do
      it 'returns the survey' do
        device = create(:device, udid: udid)
        create(:submission, device_id: device.id, survey_id: survey.id, closed_by_user: true)

        json_response = make_call
        found_survey?(json_response)
      end
    end

    describe 'without submission' do
      it 'returns the survey' do
        json_response = make_call
        found_survey?(json_response)
      end
    end
  end
end
