# frozen_string_literal: true
require 'spec_helper'

describe Control::SurveyLocaleGroupsController do
  describe "POST #create" do
    it 'is inaccessible to reporting-only users' do
      user = create(:reporting_only_user)
      sign_in user
      base_survey = create(:survey, account: user.account)
      old_survey_locale_group_count = SurveyLocaleGroup.count

      post :create, params: { survey_locale_group: { name: "a new group name" }, survey_id: base_survey.id }

      base_survey.reload

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(dashboard_url)

      expect(base_survey.survey_locale_group_id).to be_nil
      expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count)
    end

    it 'is accessible to full access users' do
      user = create(:user)
      sign_in user
      base_survey = create(:survey, account: user.account)
      survey_locale_group_name = "a new group name"
      old_survey_locale_group_count = SurveyLocaleGroup.count

      post :create, params: { survey_locale_group: { name: "a new group name" }, survey_id: base_survey.id }

      base_survey.reload

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(localization_editor_url(base_survey.survey_locale_group_id))

      expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count + 1)
      expect(SurveyLocaleGroup.last.name).to eq(survey_locale_group_name)
      expect(base_survey.survey_locale_group_id).to eq(SurveyLocaleGroup.last.id)
    end

    it 'is inaccessible to users not belonging to account that created the survey' do
      user = create(:user)
      sign_in user
      base_survey = create(:survey_with_account)
      old_survey_locale_group_count = SurveyLocaleGroup.count

      post :create, params: { survey_locale_group: { name: "a new group name" }, survey_id: base_survey.id }

      base_survey.reload

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(dashboard_url)

      expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count)
      expect(base_survey.survey_locale_group_id).to be_nil
    end

    it 'does not localize a survey when a required parameter is not provided' do
      user = create(:user)
      sign_in user
      base_survey = create(:survey, account: user.account)
      old_survey_locale_group_count = SurveyLocaleGroup.count

      required_params = {
        survey_locale_group: {
          name: "a new group name"
        },
        survey_id: base_survey.id
      }

      post :create, params: required_params.merge(survey_id: nil)

      base_survey.reload

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(dashboard_url)

      expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count)
      expect(base_survey.survey_locale_group_id).to be_nil

      post :create, params: required_params.deep_merge(survey_locale_group: { name: nil })

      base_survey.reload

      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to eq(dashboard_url)

      expect(SurveyLocaleGroup.count).to eq(old_survey_locale_group_count)
      expect(base_survey.survey_locale_group_id).to be_nil
    end
  end

  describe "POST #inline_edit" do
    it 'is not possible for reporting only users' do
      @user = create(:reporting_only_user)
      sign_in @user
      survey = create(:localized_survey, account: @user.account)
      survey_locale_group = survey.survey_locale_group

      old_name = survey_locale_group.name
      new_name = "new name"

      post :inline_edit, params: { id: survey_locale_group.id, survey_locale_group: { name: new_name }}
      survey_locale_group.reload

      expect(response).to have_http_status(:found)
      expect(survey_locale_group.name).to eq old_name
    end

    it 'is possible for full access users' do
      @user = create(:user)
      sign_in @user
      survey = create(:localized_survey, account: @user.account)
      survey_locale_group = survey.survey_locale_group

      new_name = "new name"

      post :inline_edit, params: { id: survey_locale_group.id, survey_locale_group: { name: new_name }}
      survey_locale_group.reload

      expect(response).to have_http_status(:ok)
      expect(survey_locale_group.name).to eq new_name
    end

    it 'is not possible for full access users from a different account' do
      @user = create(:user)
      sign_in @user
      survey = create(:localized_survey, account: create(:account))
      survey_locale_group = survey.survey_locale_group

      old_name = survey_locale_group.name
      new_name = "new name"

      post :inline_edit, params: { id: survey_locale_group.id, survey_locale_group: { name: new_name }}
      survey_locale_group.reload

      expect(response).to have_http_status(:not_found)
      expect(survey_locale_group.name).to eq old_name
    end
  end
end
