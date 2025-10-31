# frozen_string_literal: true
require 'spec_helper'

describe Control::LocaleTranslationCachesController do
  before do
    Account.delete_all
    User.delete_all
    Survey.delete_all
    Question.delete_all
    PossibleAnswer.delete_all
    LocaleTranslationCache.delete_all
  end

  describe "GET #look_up" do
    def cache_params(survey)
      params = {
        record_id: survey.id,
        column: "thank_you",
        record_type: "Survey"
      }
    end

    describe "authorization" do
      it 'is inaccessible to users not belonging to account that created the survey' do
        user = create(:user)
        sign_in user

        base_survey = create(:localized_survey, account: create(:account))

        params = cache_params(base_survey)
        create(:locale_translation_cache, params)

        get :look_up, params: params

        it_redirects_to_dashboard
      end

      it 'is accessible to reporting-only users' do
        user = create(:reporting_only_user)
        sign_in user

        base_survey = create(:localized_survey, account: user.account)

        params = cache_params(base_survey)
        cache_record = create(:locale_translation_cache, params)

        get :look_up, params: params

        it_succeeds_with_translation(cache_record.translation)
      end

      it 'is accessible to full access users' do
        user = create(:user)
        sign_in user

        base_survey = create(:localized_survey, account: user.account)

        params = cache_params(base_survey)
        cache_record = create(:locale_translation_cache, params)

        get :look_up, params: params

        it_succeeds_with_translation(cache_record.translation)
      end
    end

    describe "results" do
      it "handles missing records gracefully" do
        user = create(:user)
        sign_in user

        base_survey = create(:localized_survey, account: user.account)

        params = cache_params(base_survey)

        get :look_up, params: params

        it_fails_with_error_message("error retrieving translation -- contact admin for details")
      end
    end
  end

  def it_redirects_to_dashboard
    expect(response).to have_http_status(:found)
    expect(response.headers["Location"]).to eq(dashboard_url)
  end

  def it_fails_with_error_message(msg)
    expect(response).to have_http_status(:not_found)
    expect(json_response.try(:[], "error")).to include(msg)
  end

  def it_succeeds_with_translation(msg)
    expect(response).to have_http_status(:ok)
    expect(json_response.try(:[], "translation")).to eq(msg)
  end
end
