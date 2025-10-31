# frozen_string_literal: true
require 'spec_helper'

describe SurveySubmissionCacheWorker do
  let(:account) { create(:account) }
  let(:first_survey) { create(:survey, account: account) }
  let(:second_survey) { create(:survey, account: account) }

  before do
    Sidekiq::Worker.clear_all
    @worker = described_class.new

    # The "expects" that check applied_to_date fail if run around midnight UTC
    # due to the column set to the previous day
    travel_to Time.current.beginning_of_day + 1.hour
  end

  after do
    travel_back
  end

  it 'creates records' do
    in_scope = 10.minutes.ago
    viewed_impression = create(:submission, survey_id: first_survey.id, created_at: in_scope, viewed_at: in_scope)
    submission = create(:submission, survey_id: first_survey.id, created_at: in_scope, viewed_at: in_scope, answers_count: 1)

    out_of_scope = 1.minute.after
    create(:submission, survey_id: first_survey.id, created_at: out_of_scope)
    create(:submission, survey_id: second_survey.id, created_at: out_of_scope)

    expect(Rollbar).not_to receive(:error)
    @worker.perform

    expect(SurveySubmissionCache.count).to eq 1

    cache_record = SurveySubmissionCache.first

    expect(cache_record.impression_count).to eq 2
    expect(cache_record.viewed_impression_count).to eq 2
    expect(cache_record.submission_count).to eq 1
    expect(cache_record.survey_id).to eq first_survey.id
    expect(cache_record.applies_to_date).to eq Time.current.to_date
    expect(cache_record.last_submission_at.to_s).to eq submission.created_at.to_s
    expect(cache_record.last_impression_at.to_s).to eq submission.created_at.to_s
  end

  context "when a record exists" do
    let(:cached_submission_count) { 6 }
    let(:cached_viewed_impression_count) { 9 }
    let(:cached_impression_count) { 12 }
    let(:in_scope) { 10.minutes.ago }

    before do
      # make a cache record for this day
      @cache_record = create(
        :survey_submission_cache,
        survey_id: first_survey.id,
        applies_to_date: Time.current.to_date,
        submission_count: cached_submission_count,
        viewed_impression_count: cached_viewed_impression_count,
        impression_count: cached_impression_count,
        last_impression_at: Time.current.beginning_of_day,
        last_submission_at: Time.current.beginning_of_day
      )
    end

    context "when submissions are found" do
      before do
        # make submissions to add to the cache
        _new_impression = create(:submission, survey_id: first_survey.id, created_at: in_scope)
        _new_viewed_impression = create(:submission, survey_id: first_survey.id, created_at: in_scope, viewed_at: in_scope)
        @new_submission = create(:submission, survey_id: first_survey.id, created_at: in_scope, viewed_at: in_scope, answers_count: 1)

        out_of_scope = 1.minute.after
        create(:submission, survey_id: first_survey.id, created_at: out_of_scope)
        create(:submission, survey_id: second_survey.id, created_at: out_of_scope)

        @worker.perform

        @cache_record.reload
      end

      it "updates records" do
        expect(SurveySubmissionCache.count).to eq 1

        expect(@cache_record.impression_count).to eq cached_impression_count + 3
        expect(@cache_record.viewed_impression_count).to eq cached_viewed_impression_count + 2
        expect(@cache_record.submission_count).to eq cached_submission_count + 1
        expect(@cache_record.survey_id).to eq first_survey.id
        expect(@cache_record.last_impression_at.to_s).to eq @new_submission.created_at.to_s
        expect(@cache_record.applies_to_date).to eq Time.current.to_date
        expect(@cache_record.last_submission_at.to_s).to eq @new_submission.created_at.to_s
      end
    end

    context "when no submissions are found" do
      before do
        # make impression to trigger update of cache record
        _new_impression = create(:submission, survey_id: first_survey.id, created_at: in_scope)

        @worker.perform

        @cache_record.reload
      end

      it "does not overwrite last_submission_at with nil" do
        expect(@cache_record.last_submission_at).not_to be_nil
      end
    end
  end

  describe "run more than once in the last 10 minutes" do
    before do
      create(
        :survey_submission_cache,
        survey_id: first_survey.id,
        applies_to_date: Time.current.to_date,
        submission_count: 1,
        viewed_impression_count: 1,
        impression_count: 1,
        last_impression_at: 1.minute.ago
      )

      in_scope = 10.minutes.ago
      create(:submission, survey_id: first_survey.id, created_at: in_scope)
    end

    it "generates a rollbar error" do
      expect(Rollbar).to receive(:error)

      @worker.perform
    end

    it "generates no rollbar error if it was run by an admin" do
      expect(Rollbar).not_to receive(:error)

      @worker.perform(Time.current.beginning_of_day, Time.current.end_of_day)
    end

    it "generates only one rollbar error for multiple surveys" do
      expect(Rollbar).to receive(:error).once

      create(
        :survey_submission_cache,
        survey_id: second_survey.id,
        applies_to_date: Time.current.to_date,
        submission_count: 1,
        viewed_impression_count: 1,
        impression_count: 1,
        last_impression_at: 1.minute.ago
      )

      in_scope = 10.minutes.ago
      create(:submission, survey_id: second_survey.id, created_at: in_scope)

      @worker.perform
    end
  end

  describe "Recurring Backfilling" do
    let(:within_interval) { Time.current - rand(described_class::WorkerInterval) }
    let(:out_of_interval) { rand(Time.current.beginning_of_day...(Time.current - described_class::WorkerInterval)) }

    let(:survey) { create(:survey) }
    let(:impressions) { create_list(:submission, 5, survey: survey, created_at: out_of_interval) }

    context 'when a survey served in a previous interval has been viewed in the current interval' do
      before do
        @cache = create(:survey_submission_cache, survey: survey, applies_to_date: Date.today,
                 impression_count: impressions.count, viewed_impression_count: survey.viewed_impressions.count)

        @old_viewed_impression_count = survey.viewed_impressions.count
        impressions.each { |impression| impression.update(viewed_at: within_interval) }
        @new_viewed_impression_count = survey.reload.viewed_impressions.count
      end

      it 'backfills the cached viewed impression counts' do
        expect { @worker.perform }.to change { @cache.reload.viewed_impression_count }.from(@old_viewed_impression_count).to(@new_viewed_impression_count)
      end
    end

    context 'when a survey served in a previous interval has been answered in the current interval' do
      before do
        @cache = create(:survey_submission_cache, survey: survey, applies_to_date: Date.today,
                 impression_count: impressions.count, submission_count: survey.submissions.count)

        @old_submission_count = survey.submissions.count
        impressions.each { |impression| create(:answer, submission: impression, created_at: within_interval) }
        @new_submission_count = survey.reload.submissions.count
      end

      it 'backfills the cached submission counts' do
        expect { @worker.perform }.to change { @cache.reload.submission_count }.from(@old_submission_count).to(@new_submission_count)
      end

      it 'updates last_submission_at' do
        @worker.perform
        expect(@cache.reload.last_submission_at).to eq survey.reload.submissions.maximum(:created_at)
      end
    end
  end
end
