# frozen_string_literal: true
require 'spec_helper'

describe Control::SurveyIndexPresenter do
  before do
    @survey = create(:survey, account: user.account)
    survey_scope = user.account.surveys
    stored_filters = {}
    audits = []
    date_range = nil

    @presenter = described_class.new(survey_scope, user, stored_filters, audits, date_range)
  end

  describe 'dashboard_props' do
    let(:user) { create(:admin) } # cacheDetails are only available to admin

    before do
      create(:survey_submission_cache, survey: @survey)

      @dashboard_props = @presenter.dashboard_props
    end

    it 'returns a time period of up to 10 minutes before the next cache update starts' do
      next_cache_message = @dashboard_props[:cacheDetails][:nextGlobalCache]
      minutes_until_next_cache = next_cache_message.scan(/\d+/).first.to_i
      expect(minutes_until_next_cache).to be <= 10 # Because it runs every 10 minutes
    end
  end

  describe "survey_data_for_table" do
    let(:viewed_impressions_enabled_at) { FFaker::Time.datetime }
    let(:account) { create(:account, viewed_impressions_enabled_at: viewed_impressions_enabled_at) }
    let(:user) { create(:user, account: account) }

    before do
      Audited.audit_class.as_user(user) do
        @survey.update(name: FFaker::Lorem.phrase)
      end

      (viewed_impressions_enabled_at - 2.days..viewed_impressions_enabled_at + 2.days).each do |date|
        create(:survey_submission_cache, survey: @survey, applies_to_date: date)
      end

      @table_data = @presenter.survey_data_for_table(@survey)
    end

    it "returns accurate keys" do
      table_keys = %i(
        type id name status goal updatedAt updatedByName rowLinks tags
        createdByName possibleAnswerIds impressions submissions lastImpression
        lastSubmission submissionRate searchableContent liveAt
      )

      expect(@table_data.keys).to eq(table_keys)
    end

    it "returns unique question and possible answer content" do
      searchable_content = (@survey.questions.pluck(:content) + @survey.possible_answers.pluck(:content)).uniq
      expect(@table_data[:searchableContent].sort).to eq(searchable_content.sort)
    end

    it "returns the name of the survey's last editor" do
      expect(@table_data[:updatedByName]).to eq(@survey.updated_by_name)
    end

    it 'blends served & viewed impressions' do
      expect(@table_data[:impressions]).to eq(@survey.cached_blended_impressions_count)
    end
  end
end
